// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:agent_skills/models/marketplace_skill.dart';
import 'package:http/http.dart' as http;

/// Service for fetching skill listings from online marketplaces
/// (skills.sh and ClawHub).
///
/// Replaces the Rust marketplace/skillssh.rs and marketplace/clawhub.rs modules.
class MarketplaceService {
  final http.Client _client;

  /// Simple in-memory cache with TTL (replaces the Rust SQLite marketplace cache).
  final Map<String, _CacheEntry> _cache = {};
  static const _cacheTtl = Duration(minutes: 5);

  MarketplaceService({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch skills from skills.sh leaderboard.
  Future<List<MarketplaceSkill>> fetchSkillsSh({
    String sort = 'all-time',
    int page = 1,
  }) async {
    final cacheKey = 'skills.sh:$sort:$page';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      // Use the skills.sh JSON API endpoint
      final uri = Uri.parse(
        'https://skills.sh/api/leaderboard?sort=$sort&page=$page',
      );
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data is List ? data : (data['skills'] ?? []);
        final skills = items
            .map((item) => MarketplaceSkill.fromMap(
                  item as Map<String, dynamic>,
                  'skills.sh',
                ))
            .toList();
        _putInCache(cacheKey, skills);
        return skills;
      }
    } catch (_) {
      // Fall through to empty list on error
    }
    return [];
  }

  /// Fetch skills from ClawHub marketplace.
  Future<List<MarketplaceSkill>> fetchClawHub({
    String sort = 'default',
    int page = 1,
  }) async {
    final cacheKey = 'clawhub:$sort:$page';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        'https://api.clawhub.ai/v1/skills?sort=$sort&page=$page',
      );
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data is List ? data : (data['skills'] ?? []);
        final skills = items
            .map((item) => MarketplaceSkill.fromMap(
                  item as Map<String, dynamic>,
                  'clawhub',
                ))
            .toList();
        _putInCache(cacheKey, skills);
        return skills;
      }
    } catch (_) {
      // Fall through
    }
    return [];
  }

  /// Search across a marketplace source.
  Future<List<MarketplaceSkill>> searchMarketplace(
    String query,
    String source,
  ) async {
    if (query.isEmpty) return [];

    try {
      final Uri uri;
      if (source == 'skills.sh') {
        uri = Uri.parse(
          'https://skills.sh/api/search?q=${Uri.encodeComponent(query)}',
        );
      } else {
        uri = Uri.parse(
          'https://api.clawhub.ai/v1/skills/search?q=${Uri.encodeComponent(query)}',
        );
      }

      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data is List ? data : (data['skills'] ?? []);
        return items
            .map((item) => MarketplaceSkill.fromMap(
                  item as Map<String, dynamic>,
                  source,
                ))
            .toList();
      }
    } catch (_) {
      // Fall through
    }
    return [];
  }

  /// Fetch remote SKILL.md content from a Git repository URL.
  Future<String> fetchRemoteSkillContent(
    String repoUrl, {
    String? skillName,
  }) async {
    try {
      // Convert GitHub URL to raw content URL
      String rawUrl = repoUrl;
      if (repoUrl.contains('github.com')) {
        rawUrl = repoUrl
            .replaceFirst('github.com', 'raw.githubusercontent.com')
            .replaceFirst(RegExp(r'\.git$'), '');
        final path = skillName != null ? '$skillName/' : '';
        rawUrl = '$rawUrl/main/${path}SKILL.md';
      }

      final response = await _client.get(Uri.parse(rawUrl));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (_) {
      // Fall through
    }
    return '';
  }

  /// Clear the in-memory marketplace cache.
  void clearCache() {
    _cache.clear();
  }

  // --- Cache helpers ---

  List<MarketplaceSkill>? _getFromCache(String key) {
    final entry = _cache[key];
    if (entry != null && DateTime.now().difference(entry.timestamp) < _cacheTtl) {
      return entry.data;
    }
    _cache.remove(key);
    return null;
  }

  void _putInCache(String key, List<MarketplaceSkill> data) {
    _cache[key] = _CacheEntry(data: data, timestamp: DateTime.now());
  }
}

class _CacheEntry {
  final List<MarketplaceSkill> data;
  final DateTime timestamp;

  _CacheEntry({required this.data, required this.timestamp});
}
