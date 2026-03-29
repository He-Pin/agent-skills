// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

/// Represents the skill format used by an agent.
enum SkillFormat {
  skillMd,
  geminiExtension,
}

/// Configuration for a single AI agent (e.g., Claude Code, Cursor).
/// Loaded from bundled TOML config files or hardcoded defaults.
class AgentConfig {
  final String slug;
  final String name;
  final bool enabled;
  final List<String> globalPaths;
  final SkillFormat skillFormat;
  final String? cliCommand;
  final String? installCommand;
  final String? installDocsUrl;
  final String? installSourceLabel;
  bool detected;

  AgentConfig({
    required this.slug,
    required this.name,
    this.enabled = true,
    required this.globalPaths,
    this.skillFormat = SkillFormat.skillMd,
    this.cliCommand,
    this.installCommand,
    this.installDocsUrl,
    this.installSourceLabel,
    this.detected = false,
  });

  /// Create from a TOML-parsed map.
  factory AgentConfig.fromMap(Map<String, dynamic> map) {
    return AgentConfig(
      slug: map['slug'] as String,
      name: map['name'] as String,
      enabled: map['enabled'] as bool? ?? true,
      globalPaths: (map['global_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      skillFormat: map['skill_format'] == 'gemini-extension'
          ? SkillFormat.geminiExtension
          : SkillFormat.skillMd,
      cliCommand: map['cli_command'] as String?,
      installCommand: map['install_command'] as String?,
      installDocsUrl: map['install_docs_url'] as String?,
      installSourceLabel: map['install_source_label'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'slug': slug,
        'name': name,
        'enabled': enabled,
        'global_paths': globalPaths,
        'skill_format':
            skillFormat == SkillFormat.geminiExtension ? 'gemini-extension' : 'skill-md',
        if (cliCommand != null) 'cli_command': cliCommand,
        if (installCommand != null) 'install_command': installCommand,
        if (installDocsUrl != null) 'install_docs_url': installDocsUrl,
        if (installSourceLabel != null) 'install_source_label': installSourceLabel,
        'detected': detected,
      };
}
