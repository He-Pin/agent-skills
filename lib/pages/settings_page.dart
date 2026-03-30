// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:agent_skills/i18n/app_localizations.dart';
import 'package:agent_skills/providers/app_provider.dart';
import 'package:agent_skills/theme/app_theme.dart';
import 'package:agent_skills/widgets/glass_panel.dart';
import 'package:agent_skills/widgets/toast_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings page - application configuration and repository management.
///
/// Features:
/// - Theme selection (Light / Dark / System)
/// - Accent color presets (6 options)
/// - Language switcher (English / Chinese)
/// - Marketplace cache management
/// - Skill source (repo) management
/// - About section
///
/// Replaces Settings.tsx from the React app.
class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String accentKey;
  final ValueChanged<String> onAccentChanged;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.accentKey,
    required this.onAccentChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _cacheCleared = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<AppProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text(
          l.t('settings.title'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),

        // --- Theme ---
        _SettingsSection(
          title: l.t('settings.theme'),
          child: Row(
            children: [
              _ThemeOption(
                label: l.t('settings.light'),
                icon: Icons.light_mode_rounded,
                selected: widget.themeMode == ThemeMode.light,
                onTap: () => widget.onThemeModeChanged(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: l.t('settings.dark'),
                icon: Icons.dark_mode_rounded,
                selected: widget.themeMode == ThemeMode.dark,
                onTap: () => widget.onThemeModeChanged(ThemeMode.dark),
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: l.t('settings.system'),
                icon: Icons.brightness_auto_rounded,
                selected: widget.themeMode == ThemeMode.system,
                onTap: () =>
                    widget.onThemeModeChanged(ThemeMode.system),
              ),
            ],
          ),
        ),

        // --- Accent Color ---
        _SettingsSection(
          title: l.t('settings.accentColor'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accentPresets.map((preset) {
              final isSelected = widget.accentKey == preset.key;
              return GestureDetector(
                onTap: () => widget.onAccentChanged(preset.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 80,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? preset.lightPrimary.withValues(alpha: 0.12)
                        : onSurface.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? preset.lightPrimary.withValues(alpha: 0.4)
                          : onSurface.withValues(alpha: 0.08),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? preset.darkPrimary
                              : preset.lightPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _accentLabel(l, preset.key),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? (isDark
                                  ? preset.darkPrimary
                                  : preset.lightPrimary)
                              : onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // --- Language ---
        _SettingsSection(
          title: l.t('settings.language'),
          child: Row(
            children: [
              _LanguageOption(
                label: 'English',
                selected: widget.locale.languageCode == 'en',
                onTap: () => widget.onLocaleChanged(const Locale('en')),
              ),
              const SizedBox(width: 8),
              _LanguageOption(
                label: '中文',
                selected: widget.locale.languageCode == 'zh',
                onTap: () =>
                    widget.onLocaleChanged(const Locale('zh', 'CN')),
              ),
            ],
          ),
        ),

        // --- Marketplace Cache ---
        _SettingsSection(
          title: l.t('settings.marketplaceCache'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('settings.cacheDescription'),
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cacheCleared
                    ? null
                    : () {
                        provider.clearMarketplaceCache();
                        setState(() => _cacheCleared = true);
                        Future.delayed(
                          const Duration(seconds: 2),
                          () {
                            if (mounted) {
                              setState(() => _cacheCleared = false);
                            }
                          },
                        );
                      },
                icon: Icon(
                  _cacheCleared ? Icons.check : Icons.delete_outline,
                  size: 16,
                ),
                label: Text(
                  _cacheCleared
                      ? l.t('settings.cleared')
                      : l.t('settings.clearCache'),
                ),
              ),
            ],
          ),
        ),

        // --- Skill Sources (Repos) ---
        _SettingsSection(
          title: l.t('repos.skillRepos'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('repos.reposDescription'),
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              if (provider.repos.isEmpty)
                Text(
                  l.t('repos.noRepos'),
                  style: TextStyle(
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.4),
                  ),
                )
              else
                ...provider.repos.map((repo) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InteractiveGlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            repo.repoUrl.isNotEmpty
                                ? Icons.cloud_outlined
                                : Icons.folder_outlined,
                            size: 18,
                            color: onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  repo.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1),
                                      decoration: BoxDecoration(
                                        color: onSurface
                                            .withValues(alpha: 0.06),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        repo.repoUrl.isNotEmpty
                                            ? l.t('repos.gitSource')
                                            : l.t('repos.localSource'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: onSurface
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l.t('repos.skillCountLabel', {
                                        'count':
                                            '${repo.skillCount}',
                                      }),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    if (repo.lastSynced != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        l.t('repos.lastSynced', {
                                          'time': DateFormat.yMd()
                                              .add_Hm()
                                              .format(
                                                  repo.lastSynced!),
                                        }),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: onSurface
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (repo.repoUrl.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  provider.syncSkillRepo(repo.id),
                              child: Text(l.t('repos.sync'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          TextButton(
                            onPressed: () =>
                                provider.removeSkillRepo(repo.id),
                            child: Text(
                              l.t('repos.remove'),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),

        // --- Agent Skill Paths ---
        _SettingsSection(
          title: l.t('settings.agentSkillPaths'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('settings.agentPathsDescription'),
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              ...provider.agents.map((agent) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          agent.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          agent.globalPaths.join(', '),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.folder_open,
                            size: 16,
                            color: onSurface.withValues(alpha: 0.4)),
                        onPressed: () {
                          final expanded =
                              provider.agents.first.globalPaths.first;
                          launchUrl(Uri.file(expanded));
                        },
                        tooltip: l.t('settings.revealInFinder'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // --- About ---
        _SettingsSection(
          title: l.t('settings.about'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AgentSkills v0.1.4',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(
                    'https://github.com/chrlsio/agent-skills')),
                child: Text(
                  'github.com/chrlsio/agent-skills',
                  style: TextStyle(
                    fontSize: 13,
                    color: primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  String _accentLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'indigo':
        return l.t('settings.accentIndigo');
      case 'coral':
        return l.t('settings.accentCoral');
      case 'teal':
        return l.t('settings.accentTeal');
      case 'amber':
        return l.t('settings.accentAmber');
      case 'rose':
        return l.t('settings.accentRose');
      case 'mono':
        return l.t('settings.accentMono');
      default:
        return key;
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassPanel(
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ThemeOption> createState() => _ThemeOptionState();
}

class _ThemeOptionState extends State<_ThemeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? primary.withValues(alpha: 0.1)
                : _hovered
                    ? onSurface.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? primary.withValues(alpha: 0.3)
                  : onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.selected
                    ? primary
                    : onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.selected
                      ? primary
                      : onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LanguageOption> createState() => _LanguageOptionState();
}

class _LanguageOptionState extends State<_LanguageOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? primary.withValues(alpha: 0.1)
                : _hovered
                    ? onSurface.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? primary.withValues(alpha: 0.3)
                  : onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: widget.selected
                  ? primary
                  : onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
