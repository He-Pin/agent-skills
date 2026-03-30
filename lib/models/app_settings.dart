// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

/// Application-wide settings persisted to disk.
class AppSettings {
  String theme; // 'light', 'dark', 'system'
  String language; // 'en', 'zh-CN'
  Map<String, String> pathOverrides;

  AppSettings({
    this.theme = 'system',
    this.language = 'en',
    Map<String, String>? pathOverrides,
  }) : pathOverrides = pathOverrides ?? {};

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      theme: map['theme'] as String? ?? 'system',
      language: map['language'] as String? ?? 'en',
      pathOverrides: (map['path_overrides'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
    );
  }

  Map<String, dynamic> toMap() => {
        'theme': theme,
        'language': language,
        'path_overrides': pathOverrides,
      };
}
