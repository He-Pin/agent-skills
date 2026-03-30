// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:agent_skills/i18n/app_localizations.dart';
import 'package:agent_skills/pages/dashboard_page.dart';
import 'package:agent_skills/pages/marketplace_page.dart';
import 'package:agent_skills/pages/settings_page.dart';
import 'package:agent_skills/pages/skills_page.dart';
import 'package:agent_skills/providers/app_provider.dart';
import 'package:agent_skills/services/notification_service.dart';
import 'package:agent_skills/services/tray_service.dart';
import 'package:agent_skills/services/update_service.dart';
import 'package:agent_skills/theme/app_theme.dart';
import 'package:agent_skills/widgets/app_layout.dart';
import 'package:agent_skills/widgets/toast_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

/// Application version, kept in sync with pubspec.yaml.
const String appVersion = '0.1.4';

/// Open a URL in the system default browser.
Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop platforms
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(900, 600),
    center: true,
    title: 'AgentSkills',
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize system tray
  final trayService = TrayService();
  await trayService.initialize();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Start auto-update checking.
  // The version string comes from pubspec.yaml (0.1.4+1 → '0.1.4').
  final updateService = UpdateService(currentVersion: appVersion);
  trayService.setOnCheckUpdates(() async {
    final update = await updateService.checkForUpdates();
    if (update != null && update.hasUpdate) {
      await notificationService.showUpdateAvailable(
        version: update.latestVersion,
        onClick: () => _openUrl(update.releaseUrl),
      );
    } else {
      await notificationService.show(
        title: 'AgentSkills',
        body: 'You are running the latest version.',
      );
    }
  });
  updateService.startPeriodicCheck(
    onUpdateAvailable: (info) {
      notificationService.showUpdateAvailable(
        version: info.latestVersion,
        onClick: () => _openUrl(info.releaseUrl),
      );
    },
  );

  runApp(const AgentSkillsApp());
}

/// Root application widget.
///
/// Manages global state: theme mode, accent color, locale.
/// Replaces App.tsx + main.tsx from the React app.
class AgentSkillsApp extends StatefulWidget {
  const AgentSkillsApp({super.key});

  @override
  State<AgentSkillsApp> createState() => _AgentSkillsAppState();
}

class _AgentSkillsAppState extends State<AgentSkillsApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String _accentKey = 'indigo';
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final themeStr = prefs.getString('theme') ?? 'system';
      _themeMode = switch (themeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _accentKey = prefs.getString('accent_color') ?? 'indigo';
      final langStr = prefs.getString('language') ?? 'en';
      _locale = langStr.startsWith('zh')
          ? const Locale('zh', 'CN')
          : const Locale('en');
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> _setAccentKey(String key) async {
    setState(() => _accentKey = key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_color', key);
  }

  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'language',
      locale.languageCode == 'zh' ? 'zh-CN' : 'en',
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentPresets.firstWhere(
      (p) => p.key == _accentKey,
      orElse: () => accentPresets.first,
    );

    return ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: MaterialApp(
        title: 'AgentSkills',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: buildLightTheme(accent),
        darkTheme: buildDarkTheme(accent),
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
        ],
        home: ToastOverlay(
          child: _MainShell(
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
            accentKey: _accentKey,
            onAccentChanged: _setAccentKey,
            locale: _locale,
            onLocaleChanged: _setLocale,
          ),
        ),
      ),
    );
  }
}

/// Main app shell that manages page navigation.
class _MainShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String accentKey;
  final ValueChanged<String> onAccentChanged;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  const _MainShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.accentKey,
    required this.onAccentChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _selectedIndex = 0;
  String? _agentFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppLayout(
        selectedIndex: _selectedIndex,
        onNavigate: (index) => setState(() => _selectedIndex = index),
        agentFilter: _agentFilter,
        onAgentFilterChanged: (filter) =>
            setState(() => _agentFilter = filter),
        child: _buildPage(),
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return SkillsPage(agentFilter: _agentFilter);
      case 2:
        return const MarketplacePage();
      case 3:
        return SettingsPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          accentKey: widget.accentKey,
          onAccentChanged: widget.onAccentChanged,
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        );
      default:
        return DashboardPage(
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
    }
  }
}
