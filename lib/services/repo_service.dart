// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:agent_skills/models/agent_config.dart';
import 'package:agent_skills/models/skill.dart';
import 'package:agent_skills/models/skill_repo.dart';
import 'package:agent_skills/services/agent_service.dart';
import 'package:agent_skills/services/skill_service.dart';
import 'package:path/path.dart' as p;

/// Service for managing skill repositories (Git repos and local directories).
///
/// Replaces the Rust commands/repos.rs module.
class RepoService {
  final AgentService _agentService;
  final SkillService _skillService;

  RepoService(this._agentService, this._skillService);

  /// Get the app data directory for storing repos.
  String get _reposDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.skills-app', 'repos');
  }

  String get _configPath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.skills-app', 'config.json');
  }

  /// Add a Git repository by cloning it.
  ///
  /// The [url] must be a valid HTTPS or Git protocol URL to prevent
  /// flag injection attacks (e.g., URLs starting with '--').
  Future<SkillRepo> addSkillRepo(
    String url, {
    void Function(String stage)? onProgress,
  }) async {
    // Validate URL to prevent git flag injection
    if (!_isValidGitUrl(url)) {
      throw ArgumentError('Invalid Git repository URL: $url');
    }

    onProgress?.call('cloning');
    final repoId = _urlToId(url);
    final localPath = p.join(_reposDir, repoId);

    await Directory(localPath).create(recursive: true);

    // Clone the repository. The '--' separates options from positional args,
    // preventing any URL from being interpreted as a git flag.
    final result = await Process.run(
      'git',
      ['clone', '--depth', '1', '--', url, localPath],
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to clone repository: ${result.stderr}');
    }

    onProgress?.call('scanning');
    // Count skills in the cloned repo
    final skillCount = await _countSkills(localPath);

    onProgress?.call('saving');
    final repo = SkillRepo(
      id: repoId,
      name: p.basename(url.replaceAll(RegExp(r'\.git$'), '')),
      repoUrl: url,
      localPath: localPath,
      lastSynced: DateTime.now(),
      skillCount: skillCount,
    );

    await _saveRepoConfig(repo);
    return repo;
  }

  /// Add a local directory as a skill source.
  Future<SkillRepo> addLocalDir(String dirPath) async {
    final repoId = p.basename(dirPath);
    final skillCount = await _countSkills(dirPath);

    final repo = SkillRepo(
      id: repoId,
      name: p.basename(dirPath),
      repoUrl: '',
      localPath: dirPath,
      skillCount: skillCount,
    );

    await _saveRepoConfig(repo);
    return repo;
  }

  /// List all registered skill repos.
  Future<List<SkillRepo>> listSkillRepos() async {
    final config = await _loadConfig();
    final repos = config['repos'] as List<dynamic>? ?? [];
    return repos
        .map((r) => SkillRepo.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Sync a Git repo (pull latest changes).
  Future<SkillRepo> syncSkillRepo(String repoId) async {
    final repos = await listSkillRepos();
    final repo = repos.firstWhere((r) => r.id == repoId);

    if (repo.repoUrl.isNotEmpty) {
      await Process.run('git', ['pull'], workingDirectory: repo.localPath);
    }

    final skillCount = await _countSkills(repo.localPath);
    final updated = SkillRepo(
      id: repo.id,
      name: repo.name,
      description: repo.description,
      repoUrl: repo.repoUrl,
      localPath: repo.localPath,
      lastSynced: DateTime.now(),
      skillCount: skillCount,
    );

    await _updateRepoConfig(updated);
    return updated;
  }

  /// Remove a registered repo.
  Future<void> removeSkillRepo(String repoId) async {
    final config = await _loadConfig();
    final repos = config['repos'] as List<dynamic>? ?? [];
    repos.removeWhere(
        (r) => (r as Map<String, dynamic>)['id'] == repoId);
    config['repos'] = repos;
    await _saveConfig(config);

    // Also delete local clone if it's in our repos directory
    final localPath = p.join(_reposDir, repoId);
    final dir = Directory(localPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// List skills within a specific repo.
  Future<List<Skill>> listRepoSkills(String repoId) async {
    final repos = await listSkillRepos();
    final repo = repos.firstWhere((r) => r.id == repoId);
    return _scanDirForSkills(repo.localPath);
  }

  /// Install a skill from a repo to target agents.
  Future<void> installRepoSkill(
    String repoId,
    String skillId,
    List<String> targetAgentSlugs,
    List<AgentConfig> agents,
  ) async {
    final repos = await listSkillRepos();
    final repo = repos.firstWhere((r) => r.id == repoId);
    final skillPath = p.join(repo.localPath, skillId);

    await _skillService.installSkillFromPath(
      skillPath,
      targetAgentSlugs,
      agents,
    );
  }

  // --- Private helpers ---

  /// Validate that a URL is a safe Git repository URL.
  ///
  /// Only allows HTTPS, HTTP, and git:// protocol URLs to prevent
  /// flag injection (e.g., a URL starting with '--upload-pack=...').
  bool _isValidGitUrl(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith('https://') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('git://') ||
        trimmed.startsWith('git@');
  }

  String _urlToId(String url) {
    return url
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'\.git$'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
  }

  Future<int> _countSkills(String dirPath) async {
    int count = 0;
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0;

    await for (final entry in dir.list()) {
      if (entry is Directory) {
        final skillMd = File(p.join(entry.path, 'SKILL.md'));
        if (await skillMd.exists()) {
          count++;
        }
      }
    }
    return count;
  }

  Future<List<Skill>> _scanDirForSkills(String dirPath) async {
    final skills = <Skill>[];
    final dir = Directory(dirPath);
    if (!await dir.exists()) return skills;

    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final skillMd = File(p.join(entry.path, 'SKILL.md'));
      if (!await skillMd.exists()) continue;

      final id = p.basename(entry.path);
      skills.add(Skill(
        id: id,
        name: id,
        canonicalPath: entry.path,
        scope: const SkillScope(type: SkillScopeType.sharedGlobal),
      ));
    }
    return skills;
  }

  Future<Map<String, dynamic>> _loadConfig() async {
    final file = File(_configPath);
    if (await file.exists()) {
      try {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Future<void> _saveConfig(Map<String, dynamic> config) async {
    final file = File(_configPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config));
  }

  Future<void> _saveRepoConfig(SkillRepo repo) async {
    final config = await _loadConfig();
    final repos = config['repos'] as List<dynamic>? ?? [];
    repos.add(repo.toMap());
    config['repos'] = repos;
    await _saveConfig(config);
  }

  Future<void> _updateRepoConfig(SkillRepo updated) async {
    final config = await _loadConfig();
    final repos = config['repos'] as List<dynamic>? ?? [];
    final index =
        repos.indexWhere((r) => (r as Map<String, dynamic>)['id'] == updated.id);
    if (index >= 0) {
      repos[index] = updated.toMap();
    } else {
      repos.add(updated.toMap());
    }
    config['repos'] = repos;
    await _saveConfig(config);
  }
}
