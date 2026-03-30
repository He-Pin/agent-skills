// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:agent_skills/models/app_settings.dart';
import 'package:path/path.dart' as p;

/// Service for reading and writing application settings.
///
/// Settings are stored in ~/.skills-app/config.json (same location as the
/// original Rust config.toml, but using JSON for simpler Dart interop).
class SettingsService {
  String get _configPath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.skills-app', 'config.json');
  }

  /// Read settings from disk.
  Future<AppSettings> readSettings() async {
    try {
      final file = File(_configPath);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        return AppSettings.fromMap(json as Map<String, dynamic>);
      }
    } catch (_) {
      // Return defaults on any error
    }
    return AppSettings();
  }

  /// Write settings to disk.
  Future<void> writeSettings(AppSettings settings) async {
    final file = File(_configPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toMap()),
    );
  }
}
