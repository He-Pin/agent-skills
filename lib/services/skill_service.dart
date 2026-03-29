// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:agent_skills/models/agent_config.dart';
import 'package:agent_skills/models/skill.dart';
import 'package:agent_skills/services/agent_service.dart';
import 'package:path/path.dart' as p;

/// Service for scanning, installing, uninstalling, and syncing skills
/// across AI agent directories.
///
/// Replaces the Rust scanner/engine.rs and installer/ modules.
class SkillService {
  final AgentService _agentService;

  SkillService(this._agentService);

  /// Scan all skills across all detected agents.
  /// Mirrors the Rust scan_all_skills() logic: iterate each agent's global_paths,
  /// find SKILL.md files, resolve symlinks, merge installations, deduplicate by ID.
  Future<List<Skill>> scanAllSkills(List<AgentConfig> agents) async {
    final Map<String, Skill> skillMap = {};

    for (final agent in agents) {
      if (!agent.detected) continue;

      for (final gp in agent.globalPaths) {
        final expanded = _agentService.expandHome(gp);
        final dir = Directory(expanded);
        if (!await dir.exists()) continue;

        await for (final entry in dir.list()) {
          if (entry is! Directory) continue;

          final skillId = p.basename(entry.path);
          final canonicalPath = await _resolveCanonical(entry.path);
          final isSymlink = await _isSymlink(entry.path);

          // Parse SKILL.md for metadata
          final skillMdPath = p.join(entry.path, 'SKILL.md');
          String name = skillId;
          String? description;
          Map<String, dynamic>? metadata;

          if (await File(skillMdPath).exists()) {
            final parsed = await _parseSkillMd(skillMdPath);
            name = parsed['name'] ?? skillId;
            description = parsed['description'];
            metadata = parsed['metadata'];
          }

          final installation = SkillInstallation(
            agentSlug: agent.slug,
            path: entry.path,
            isSymlink: isSymlink,
          );

          if (skillMap.containsKey(skillId)) {
            // Merge installation into existing skill
            final existing = skillMap[skillId]!;
            final mergedInstalls = [
              ...existing.installations,
              installation,
            ];
            skillMap[skillId] = Skill(
              id: existing.id,
              name: existing.name,
              description: existing.description,
              canonicalPath: existing.canonicalPath,
              source: existing.source,
              metadata: existing.metadata,
              scope: mergedInstalls.length > 1
                  ? const SkillScope(type: SkillScopeType.sharedGlobal)
                  : existing.scope,
              installations: mergedInstalls,
            );
          } else {
            skillMap[skillId] = Skill(
              id: skillId,
              name: name,
              description: description,
              canonicalPath: canonicalPath,
              metadata: metadata,
              scope: SkillScope(
                type: SkillScopeType.agentLocal,
                agent: agent.slug,
              ),
              installations: [installation],
            );
          }
        }
      }
    }

    return skillMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Scan skills for a specific agent.
  Future<List<Skill>> scanAgentSkills(
    String agentSlug,
    List<AgentConfig> agents,
  ) async {
    final all = await scanAllSkills(agents);
    return all
        .where(
            (s) => s.installations.any((i) => i.agentSlug == agentSlug))
        .toList();
  }

  /// Install a skill from a source path to target agents.
  /// Copies the skill directory into each agent's first global_path.
  Future<void> installSkillFromPath(
    String sourcePath,
    List<String> targetAgentSlugs,
    List<AgentConfig> agents,
  ) async {
    for (final slug in targetAgentSlugs) {
      final agent = agents.firstWhere((a) => a.slug == slug);
      if (agent.globalPaths.isEmpty) continue;

      final targetDir = _agentService.expandHome(agent.globalPaths.first);
      await Directory(targetDir).create(recursive: true);

      final skillName = p.basename(sourcePath);
      final destPath = p.join(targetDir, skillName);

      // Copy directory recursively
      await _copyDirectory(Directory(sourcePath), Directory(destPath));
    }
  }

  /// Uninstall a skill from a specific agent.
  Future<void> uninstallSkill(
    String skillPath,
    String agentSlug,
    List<AgentConfig> agents,
  ) async {
    final dir = Directory(skillPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Uninstall a skill from all agents.
  Future<void> uninstallAll(
    String skillId,
    List<Skill> skills,
  ) async {
    final skill = skills.firstWhere((s) => s.id == skillId);
    for (final installation in skill.installations) {
      final dir = Directory(installation.path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  /// Sync a skill to additional agents by copying from canonical path.
  Future<void> syncSkill(
    String canonicalPath,
    List<String> targetAgentSlugs,
    List<AgentConfig> agents,
  ) async {
    await installSkillFromPath(canonicalPath, targetAgentSlugs, agents);
  }

  /// Read the SKILL.md content for a given path.
  Future<String> readSkillContent(String skillPath) async {
    final file = File(p.join(skillPath, 'SKILL.md'));
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  /// Write SKILL.md content.
  Future<void> writeSkillContent(String skillPath, String content) async {
    final file = File(p.join(skillPath, 'SKILL.md'));
    await file.writeAsString(content);
  }

  // --- Private helpers ---

  Future<String> _resolveCanonical(String path) async {
    try {
      final link = Link(path);
      if (await link.exists()) {
        return await link.resolveSymbolicLinks();
      }
    } catch (_) {
      // Not a symlink; use as-is
    }
    return path;
  }

  Future<bool> _isSymlink(String path) async {
    try {
      return await FileSystemEntity.isLink(path);
    } catch (_) {
      return false;
    }
  }

  /// Parse SKILL.md frontmatter (YAML between --- markers).
  Future<Map<String, dynamic>> _parseSkillMd(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      final result = <String, dynamic>{};

      if (content.startsWith('---')) {
        final endIndex = content.indexOf('---', 3);
        if (endIndex != -1) {
          final frontmatter = content.substring(3, endIndex).trim();
          for (final line in frontmatter.split('\n')) {
            final colonIndex = line.indexOf(':');
            if (colonIndex > 0) {
              final key = line.substring(0, colonIndex).trim();
              final value = line.substring(colonIndex + 1).trim();
              result[key] = value;
            }
          }
        }
      }

      return result;
    } catch (_) {
      return {};
    }
  }

  /// Recursively copy a directory.
  Future<void> _copyDirectory(Directory source, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in source.list()) {
      final newPath = p.join(dest.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
