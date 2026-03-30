// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:agent_skills/i18n/translations_en.dart';
import 'package:agent_skills/i18n/translations_zh_cn.dart';

/// Simple i18n system matching the original i18next setup.
/// Supports English and Simplified Chinese with interpolation.
class AppLocalizations {
  final Locale locale;
  late final Map<String, String> _translations;

  AppLocalizations(this.locale) {
    _translations =
        locale.languageCode == 'zh' ? translationsZhCN : translationsEN;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh', 'CN'),
  ];

  /// Translate a key, with optional interpolation.
  /// Keys use dot notation: 'dashboard.title', 'skills.filterAll', etc.
  String t(String key, [Map<String, String>? params]) {
    String value = _translations[key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{{$k}}', v);
      });
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
