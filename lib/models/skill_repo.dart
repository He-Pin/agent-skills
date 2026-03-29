// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

/// A registered skill source (Git repo or local directory).
class SkillRepo {
  final String id;
  final String name;
  final String? description;
  final String repoUrl;
  final String localPath;
  final DateTime? lastSynced;
  final int skillCount;

  const SkillRepo({
    required this.id,
    required this.name,
    this.description,
    required this.repoUrl,
    required this.localPath,
    this.lastSynced,
    this.skillCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'repo_url': repoUrl,
        'local_path': localPath,
        if (lastSynced != null) 'last_synced': lastSynced!.toIso8601String(),
        'skill_count': skillCount,
      };

  factory SkillRepo.fromMap(Map<String, dynamic> map) {
    return SkillRepo(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      repoUrl: map['repo_url'] as String? ?? '',
      localPath: map['local_path'] as String? ?? '',
      lastSynced: map['last_synced'] != null
          ? DateTime.tryParse(map['last_synced'] as String)
          : null,
      skillCount: map['skill_count'] as int? ?? 0,
    );
  }
}
