// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

/// A skill listing from an online marketplace (skills.sh or ClawHub).
class MarketplaceSkill {
  final String name;
  final String? description;
  final String? author;
  final String? repository;
  final int? installs;
  final String source; // "skills.sh" or "clawhub"
  final String? slug;

  const MarketplaceSkill({
    required this.name,
    this.description,
    this.author,
    this.repository,
    this.installs,
    required this.source,
    this.slug,
  });

  factory MarketplaceSkill.fromMap(Map<String, dynamic> map, String source) {
    return MarketplaceSkill(
      name: map['name'] as String? ?? 'Unknown',
      description: map['description'] as String?,
      author: map['author'] as String?,
      repository: map['repository'] as String? ?? map['repo_url'] as String?,
      installs: map['installs'] as int? ?? map['install_count'] as int?,
      source: source,
      slug: map['slug'] as String?,
    );
  }
}
