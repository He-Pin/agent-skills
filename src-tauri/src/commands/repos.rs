use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};

use chrono::Utc;
use git2::Repository;
use serde::Deserialize;

use crate::commands::settings::{read_settings, write_settings, RepoEntry};
use crate::installer::install::install_skill_from_path;
use crate::models::agent::AgentConfig;
use crate::models::repo::SkillRepo;
use crate::models::skill::Skill;
use crate::paths;
use crate::registry::loader::{detect_agents, load_agent_configs};
use crate::scanner::engine::scan_all_skills;

/// Directory where repos are cloned
fn repos_dir() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".skills-app")
        .join("repos")
}

/// Generate a stable ID from a repo URL — uses the repo name for readability
fn repo_id(url: &str) -> String {
    repo_name_from_url(url)
}

/// Generate a stable ID from a local directory path
fn local_dir_id(path: &str) -> String {
    let mut hasher = DefaultHasher::new();
    path.hash(&mut hasher);
    format!("local-{:016x}", hasher.finish())
}

/// Manifest file in a skill repo (optional)
#[derive(Debug, Deserialize, Default)]
struct SkillsManifest {
    name: Option<String>,
    description: Option<String>,
    skills_dir: Option<String>,
}

/// Parse skills.toml from a repo root, if present
fn parse_manifest(repo_path: &Path) -> SkillsManifest {
    let manifest_path = repo_path.join("skills.toml");
    if manifest_path.is_file() {
        if let Ok(content) = fs::read_to_string(&manifest_path) {
            if let Ok(manifest) = toml::from_str::<SkillsManifest>(&content) {
                return manifest;
            }
        }
    }
    SkillsManifest::default()
}

/// Get the skills directory within a repo clone
fn skills_root(repo_path: &Path, manifest: &SkillsManifest) -> PathBuf {
    if let Some(ref dir) = manifest.skills_dir {
        let candidate = repo_path.join(dir);
        if candidate.is_dir() {
            return candidate;
        }
    }
    // Default: try "skills/" subdir first, then repo root
    let default_dir = repo_path.join("skills");
    if default_dir.is_dir() {
        return default_dir;
    }
    repo_path.to_path_buf()
}

/// Count skill directories (directories containing SKILL.md)
fn count_skills(skills_path: &Path) -> usize {
    let Ok(entries) = fs::read_dir(skills_path) else {
        return 0;
    };
    entries
        .filter_map(|e| e.ok())
        .filter(|e| e.path().is_dir() && e.path().join("SKILL.md").is_file())
        .count()
}

/// Build a SkillRepo from local clone state
fn build_skill_repo(repo_url: &str, local_path: &Path, id: &str) -> SkillRepo {
    let manifest = parse_manifest(local_path);
    let sr = skills_root(local_path, &manifest);
    let name = manifest
        .name
        .unwrap_or_else(|| repo_name_from_url(repo_url));
    SkillRepo {
        id: id.to_string(),
        name,
        description: manifest.description,
        repo_url: repo_url.to_string(),
        local_path: local_path.to_string_lossy().to_string(),
        last_synced: None, // caller fills this in
        skill_count: count_skills(&sr),
    }
}

fn repo_name_from_url(url: &str) -> String {
    url.trim_end_matches('/')
        .rsplit('/')
        .next()
        .unwrap_or("repo")
        .trim_end_matches(".git")
        .to_string()
}

fn load_detected_agents() -> Result<Vec<AgentConfig>, String> {
    let configs = load_agent_configs(&paths::agents_dir()).map_err(|e| e.to_string())?;
    Ok(detect_agents(&configs))
}

// ─── Tauri Commands ───

#[tauri::command]
pub fn add_skill_repo(repo_url: String) -> Result<SkillRepo, String> {
    let id = repo_id(&repo_url);
    let local_path = repos_dir().join(&id);

    // Don't re-clone if already exists
    if local_path.exists() {
        return Err(format!("Repository already added: {}", repo_url));
    }

    fs::create_dir_all(&local_path).map_err(|e| e.to_string())?;

    // Clone the repository
    Repository::clone(&repo_url, &local_path).map_err(|e| {
        // Clean up on failure
        let _ = fs::remove_dir_all(&local_path);
        format!("Failed to clone repository: {}", e)
    })?;

    let now = Utc::now().to_rfc3339();
    let mut repo = build_skill_repo(&repo_url, &local_path, &id);
    repo.last_synced = Some(now.clone());

    // Save to config
    let mut settings = read_settings().unwrap_or_default();
    let repos = settings.repos.get_or_insert_with(Vec::new);
    repos.push(RepoEntry {
        repo_url: Some(repo_url.clone()),
        local_path: None,
        last_synced: Some(now),
    });
    write_settings(settings).map_err(|e| e.to_string())?;

    Ok(repo)
}

#[tauri::command]
pub fn remove_skill_repo(repo_id_param: String) -> Result<(), String> {
    // Only delete the clone directory for git repos (local dirs are not managed by us)
    if !repo_id_param.starts_with("local-") {
        let local_path = repos_dir().join(&repo_id_param);
        if local_path.exists() {
            fs::remove_dir_all(&local_path).map_err(|e| e.to_string())?;
        }
    }

    // Remove from config
    let mut settings = read_settings().unwrap_or_default();
    if let Some(ref mut repos) = settings.repos {
        repos.retain(|r| {
            if let Some(ref lp) = r.local_path {
                local_dir_id(lp) != repo_id_param
            } else if let Some(ref url) = r.repo_url {
                repo_id(url) != repo_id_param
            } else {
                true
            }
        });
    }
    write_settings(settings).map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
pub fn list_skill_repos() -> Result<Vec<SkillRepo>, String> {
    let settings = read_settings().unwrap_or_default();
    let repo_entries = settings.repos.unwrap_or_default();

    let mut result = Vec::new();
    for entry in &repo_entries {
        if let Some(ref lp) = entry.local_path {
            let dir = Path::new(lp);
            if !dir.exists() {
                continue;
            }
            let id = local_dir_id(lp);
            let manifest = parse_manifest(dir);
            let sr = skills_root(dir, &manifest);
            let name = manifest.name.unwrap_or_else(|| {
                dir.file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_else(|| "Local".to_string())
            });
            result.push(SkillRepo {
                id,
                name,
                description: manifest.description,
                repo_url: lp.clone(),
                local_path: lp.clone(),
                last_synced: None,
                skill_count: count_skills(&sr),
            });
        } else if let Some(ref url) = entry.repo_url {
            let id = repo_id(url);
            let local_path = repos_dir().join(&id);
            if !local_path.exists() {
                continue;
            }
            let mut repo = build_skill_repo(url, &local_path, &id);
            repo.last_synced = entry.last_synced.clone();
            result.push(repo);
        }
    }

    Ok(result)
}

#[tauri::command]
pub fn sync_skill_repo(repo_id_param: String) -> Result<SkillRepo, String> {
    let local_path = repos_dir().join(&repo_id_param);
    if !local_path.exists() {
        return Err("Repository not found locally".to_string());
    }

    // Open and pull
    let repo = Repository::open(&local_path).map_err(|e| e.to_string())?;

    // Fetch origin
    let mut remote = repo.find_remote("origin").map_err(|e| e.to_string())?;
    remote
        .fetch(&["HEAD"], None, None)
        .map_err(|e| e.to_string())?;

    // Fast-forward merge
    let fetch_head = repo
        .find_reference("FETCH_HEAD")
        .map_err(|e| e.to_string())?;
    let fetch_commit = repo
        .reference_to_annotated_commit(&fetch_head)
        .map_err(|e| e.to_string())?;
    let head = repo.head().map_err(|e| e.to_string())?;
    let head_name = head.name().unwrap_or("HEAD").to_string();

    let (analysis, _) = repo
        .merge_analysis(&[&fetch_commit])
        .map_err(|e| e.to_string())?;

    if analysis.is_fast_forward() || analysis.is_normal() {
        let target_oid = fetch_commit.id();
        let target_commit = repo
            .find_object(target_oid, None)
            .map_err(|e| e.to_string())?;
        repo.checkout_tree(&target_commit, None)
            .map_err(|e| e.to_string())?;
        repo.reference(&head_name, target_oid, true, "skills-app sync")
            .map_err(|e| e.to_string())?;
    }
    // If up-to-date, nothing to do

    let now = Utc::now().to_rfc3339();

    // Update config
    let mut settings = read_settings().unwrap_or_default();
    if let Some(ref mut repos) = settings.repos {
        for entry in repos.iter_mut() {
            if entry.repo_url.as_deref().map(repo_id).as_deref() == Some(&repo_id_param) {
                entry.last_synced = Some(now.clone());
            }
        }
    }
    write_settings(settings).map_err(|e| e.to_string())?;

    // Rebuild repo info
    let settings2 = read_settings().unwrap_or_default();
    let repo_entries = settings2.repos.unwrap_or_default();
    let entry = repo_entries
        .iter()
        .find(|r| r.repo_url.as_deref().map(repo_id).as_deref() == Some(&repo_id_param));
    let repo_url = entry.and_then(|e| e.repo_url.as_deref()).unwrap_or("");

    let mut skill_repo = build_skill_repo(repo_url, &local_path, &repo_id_param);
    skill_repo.last_synced = Some(now);

    Ok(skill_repo)
}

#[tauri::command]
pub fn list_repo_skills(repo_id_param: String) -> Result<Vec<Skill>, String> {
    let local_path = if repo_id_param.starts_with("local-") {
        let settings = read_settings().unwrap_or_default();
        let repos = settings.repos.unwrap_or_default();
        let entry = repos.iter().find(|r| {
            r.local_path.as_ref().map(|lp| local_dir_id(lp)) == Some(repo_id_param.clone())
        });
        match entry.and_then(|e| e.local_path.clone()) {
            Some(p) => PathBuf::from(p),
            None => return Err("Local directory not found in config".to_string()),
        }
    } else {
        repos_dir().join(&repo_id_param)
    };

    if !local_path.exists() {
        return Err("Repository not found locally".to_string());
    }

    let manifest = parse_manifest(&local_path);
    let sr = skills_root(&local_path, &manifest);

    // Create a virtual agent config pointing to the repo's skills directory
    // so we can reuse the existing scanner
    let virtual_agent = AgentConfig {
        slug: format!("repo-{}", repo_id_param),
        name: "Repo".to_string(),
        global_paths: vec![sr.to_string_lossy().to_string()],
        detected: true,
        ..Default::default()
    };

    let skills = scan_all_skills(&[virtual_agent]).map_err(|e| e.to_string())?;
    Ok(skills)
}

#[tauri::command]
pub fn install_repo_skill(
    repo_id_param: String,
    skill_id: String,
    target_agents: Vec<String>,
) -> Result<(), String> {
    let local_path = if repo_id_param.starts_with("local-") {
        let settings = read_settings().unwrap_or_default();
        let repos = settings.repos.unwrap_or_default();
        let entry = repos.iter().find(|r| {
            r.local_path.as_ref().map(|lp| local_dir_id(lp)) == Some(repo_id_param.clone())
        });
        match entry.and_then(|e| e.local_path.clone()) {
            Some(p) => PathBuf::from(p),
            None => return Err("Local directory not found in config".to_string()),
        }
    } else {
        repos_dir().join(&repo_id_param)
    };
    if !local_path.exists() {
        return Err("Repository not found locally".to_string());
    }

    let manifest = parse_manifest(&local_path);
    let sr = skills_root(&local_path, &manifest);
    let skill_path = sr.join(&skill_id);

    if !skill_path.is_dir() || !skill_path.join("SKILL.md").is_file() {
        return Err(format!("Skill '{}' not found in repository", skill_id));
    }

    let agents = load_detected_agents()?;
    for agent_slug in &target_agents {
        install_skill_from_path(&skill_path, agent_slug, &agents).map_err(|e| e.to_string())?;
    }

    Ok(())
}

#[tauri::command]
pub fn add_local_dir(path: String) -> Result<SkillRepo, String> {
    let dir = Path::new(&path);
    if !dir.is_dir() {
        return Err("Path is not a directory".to_string());
    }

    // Check for duplicates
    let settings = read_settings().unwrap_or_default();
    if let Some(ref repos) = settings.repos {
        if repos.iter().any(|r| r.local_path.as_deref() == Some(&path)) {
            return Err("This directory is already added".to_string());
        }
    }

    let id = local_dir_id(&path);
    let manifest = parse_manifest(dir);
    let sr = skills_root(dir, &manifest);
    let name = manifest.name.unwrap_or_else(|| {
        dir.file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| "Local".to_string())
    });

    let repo = SkillRepo {
        id: id.clone(),
        name,
        description: manifest.description,
        repo_url: path.clone(),
        local_path: path.clone(),
        last_synced: None,
        skill_count: count_skills(&sr),
    };

    let mut settings = read_settings().unwrap_or_default();
    let repos = settings.repos.get_or_insert_with(Vec::new);
    repos.push(RepoEntry {
        repo_url: None,
        local_path: Some(path),
        last_synced: None,
    });
    write_settings(settings).map_err(|e| e.to_string())?;

    Ok(repo)
}
