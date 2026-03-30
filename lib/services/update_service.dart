// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents available update information.
class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseUrl;
  final String? releaseNotes;
  final Map<String, String> downloadUrls;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseUrl,
    this.releaseNotes,
    this.downloadUrls = const {},
  });

  bool get hasUpdate => _compareVersions(latestVersion, currentVersion) > 0;
}

/// Service for checking and managing application updates.
///
/// Checks the GitHub Releases API for new versions and provides
/// download URLs for each platform.
class UpdateService {
  static const _repoOwner = 'He-Pin';
  static const _repoName = 'agent-skills';
  static const _checkInterval = Duration(hours: 4);

  final http.Client _client;
  final String _currentVersion;
  Timer? _periodicTimer;
  void Function(UpdateInfo)? _onUpdateAvailable;

  UpdateService({
    required String currentVersion,
    http.Client? client,
  })  : _currentVersion = currentVersion,
        _client = client ?? http.Client();

  /// Start periodic update checks.
  void startPeriodicCheck({void Function(UpdateInfo)? onUpdateAvailable}) {
    _onUpdateAvailable = onUpdateAvailable;
    // Fire-and-forget initial check — errors are handled inside checkForUpdates
    unawaited(checkForUpdates());
    // Then check periodically
    _periodicTimer = Timer.periodic(_checkInterval, (_) {
      unawaited(checkForUpdates());
    });
  }

  /// Stop periodic update checks.
  void stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Check for updates from GitHub Releases.
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );
      final response = await _client.get(uri, headers: {
        'Accept': 'application/vnd.github.v3+json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String?) ?? '';
        final version =
            tagName.startsWith('v') ? tagName.substring(1) : tagName;
        final htmlUrl = (data['html_url'] as String?) ?? '';
        final body = data['body'] as String?;

        // Parse download URLs from assets
        final assets = data['assets'] as List<dynamic>? ?? [];
        final downloadUrls = <String, String>{};
        for (final asset in assets) {
          final name = (asset['name'] as String?) ?? '';
          final url = (asset['browser_download_url'] as String?) ?? '';
          if (name.contains('linux')) {
            downloadUrls['linux'] = url;
          } else if (name.contains('macos') || name.contains('darwin')) {
            downloadUrls['macos'] = url;
          } else if (name.contains('windows')) {
            downloadUrls['windows'] = url;
          }
        }

        final info = UpdateInfo(
          latestVersion: version,
          currentVersion: _currentVersion,
          releaseUrl: htmlUrl,
          releaseNotes: body,
          downloadUrls: downloadUrls,
        );

        if (info.hasUpdate) {
          _onUpdateAvailable?.call(info);
          return info;
        }
      }
    } catch (e) {
      // Update checks are non-critical; log for debugging only
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  void dispose() {
    stopPeriodicCheck();
  }
}

/// Number of semver components (major.minor.patch).
const _semverComponents = 3;

/// Compare two semver version strings.
/// Returns > 0 if a > b, < 0 if a < b, 0 if equal.
int _compareVersions(String a, String b) {
  final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();

  // Pad to same length
  while (aParts.length < _semverComponents) {
    aParts.add(0);
  }
  while (bParts.length < _semverComponents) {
    bParts.add(0);
  }

  for (int i = 0; i < _semverComponents; i++) {
    if (aParts[i] != bParts[i]) {
      return aParts[i] - bParts[i];
    }
  }
  return 0;
}
