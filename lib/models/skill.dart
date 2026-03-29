// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

/// Where the skill came from.
enum SkillSourceType {
  localPath,
  gitRepository,
  skillsSh,
  clawHub,
}

class SkillSource {
  final SkillSourceType type;
  final String? url;
  final String? path;

  const SkillSource({required this.type, this.url, this.path});

  Map<String, dynamic> toMap() => {
        'type': type.name,
        if (url != null) 'url': url,
        if (path != null) 'path': path,
      };

  factory SkillSource.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    return SkillSource(
      type: SkillSourceType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => SkillSourceType.localPath,
      ),
      url: map['url'] as String?,
      path: map['path'] as String?,
    );
  }
}

/// Where a skill is installed.
class SkillInstallation {
  final String agentSlug;
  final String path;
  final bool isSymlink;
  final bool isInherited;
  final String? inheritedFrom;

  const SkillInstallation({
    required this.agentSlug,
    required this.path,
    this.isSymlink = false,
    this.isInherited = false,
    this.inheritedFrom,
  });
}

/// Scope of a skill (global or agent-local).
enum SkillScopeType {
  sharedGlobal,
  agentLocal,
}

class SkillScope {
  final SkillScopeType type;
  final String? agent;

  const SkillScope({required this.type, this.agent});
}

/// A single managed skill.
class Skill {
  final String id;
  final String name;
  final String? description;
  final String canonicalPath;
  final SkillSource? source;
  final Map<String, dynamic>? metadata;
  final SkillScope scope;
  final List<SkillInstallation> installations;

  const Skill({
    required this.id,
    required this.name,
    this.description,
    required this.canonicalPath,
    this.source,
    this.metadata,
    required this.scope,
    this.installations = const [],
  });

  /// Returns agent slugs where this skill is installed.
  List<String> get installedAgentSlugs =>
      installations.map((i) => i.agentSlug).toList();
}
