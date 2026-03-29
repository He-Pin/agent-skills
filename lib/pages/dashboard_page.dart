// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:agent_skills/i18n/app_localizations.dart';
import 'package:agent_skills/models/agent_config.dart';
import 'package:agent_skills/providers/app_provider.dart';
import 'package:agent_skills/widgets/glass_panel.dart';
import 'package:agent_skills/widgets/search_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dashboard page - the home view of the app.
///
/// Shows agent detection status, skill counts, and recent skills.
/// Replaces Dashboard.tsx from the React app.
class DashboardPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const DashboardPage({super.key, this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _searchTerm = '';
  String _statusFilter = 'all'; // 'all', 'detected', 'not-installed'
  String _sortBy = 'name'; // 'name', 'skills'
  AgentConfig? _guideAgent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (provider.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l.t('dashboard.loadingAgents')),
          ],
        ),
      );
    }

    // Filter agents
    var agents = provider.agents.toList();
    if (_searchTerm.isNotEmpty) {
      final term = _searchTerm.toLowerCase();
      agents = agents.where((a) {
        return a.name.toLowerCase().contains(term) ||
            a.slug.toLowerCase().contains(term) ||
            a.globalPaths.any((p) => p.toLowerCase().contains(term));
      }).toList();
    }
    if (_statusFilter == 'detected') {
      agents = agents.where((a) => a.detected).toList();
    } else if (_statusFilter == 'not-installed') {
      agents = agents.where((a) => !a.detected).toList();
    }

    // Sort agents
    if (_sortBy == 'skills') {
      agents.sort((a, b) {
        final aCount = provider.skillsForAgent(a.slug).length;
        final bCount = provider.skillsForAgent(b.slug).length;
        return bCount.compareTo(aCount);
      });
    } else {
      agents.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(8),
          children: [
            // --- Stats Cards ---
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: l.t('dashboard.detectedAgents'),
                    value: '${provider.detectedAgents.length}',
                    subtitle: l.t('dashboard.detectedOf', {
                      'detected': '${provider.detectedAgents.length}',
                      'total': '${provider.agents.length}',
                    }),
                    icon: Icons.smart_toy_rounded,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: l.t('dashboard.installedSkills'),
                    value: '${provider.skills.length}',
                    subtitle: l.t('dashboard.skillCount', {
                      'count': '${provider.skills.length}',
                    }),
                    icon: Icons.auto_awesome_rounded,
                    color: primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- Agents Header ---
            Row(
              children: [
                Text(
                  l.t('dashboard.agents'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Tooltip(
                  message: l.t('dashboard.refreshTitle'),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: () => provider.refresh(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- Search & Filters ---
            SearchInput(
              placeholder: l.t('dashboard.searchPlaceholder'),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
            const SizedBox(height: 12),

            // Filter chips + sort
            Row(
              children: [
                _FilterChip(
                  label: l.t('dashboard.filterAll'),
                  selected: _statusFilter == 'all',
                  onTap: () => setState(() => _statusFilter = 'all'),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.t('dashboard.filterDetected'),
                  selected: _statusFilter == 'detected',
                  onTap: () => setState(() => _statusFilter = 'detected'),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.t('dashboard.filterNotInstalled'),
                  selected: _statusFilter == 'not-installed',
                  onTap: () =>
                      setState(() => _statusFilter = 'not-installed'),
                ),
                const Spacer(),
                _FilterChip(
                  label: l.t('dashboard.sortName'),
                  selected: _sortBy == 'name',
                  onTap: () => setState(() => _sortBy = 'name'),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: l.t('dashboard.sortSkills'),
                  selected: _sortBy == 'skills',
                  onTap: () => setState(() => _sortBy = 'skills'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Agent Grid ---
            if (agents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    l.t('dashboard.noAgentsMatch'),
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: agents.map((agent) {
                  final skillCount =
                      provider.skillsForAgent(agent.slug).length;
                  return _AgentCard(
                    agent: agent,
                    skillCount: skillCount,
                    onTap: agent.detected
                        ? null
                        : () => setState(() => _guideAgent = agent),
                  );
                }).toList(),
              ),

            const SizedBox(height: 32),

            // --- Recent Skills ---
            Row(
              children: [
                Text(
                  l.t('dashboard.recentSkills'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onNavigate?.call(1),
                  child: Text(l.t('dashboard.viewAll')),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (provider.skills.isEmpty)
              GlassPanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome_outlined,
                        size: 40,
                        color: onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(l.t('dashboard.noSkillsYet'),
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigate?.call(2),
                      icon: const Icon(Icons.store_rounded, size: 16),
                      label: Text(l.t('dashboard.browseMarketplace')),
                    ),
                  ],
                ),
              )
            else
              ...provider.skills.take(5).map((skill) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InteractiveGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 16, color: primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                skill.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                              if (skill.description != null)
                                Text(
                                  skill.description!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: onSurface.withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // Agent badges
                        Wrap(
                          spacing: 4,
                          children: skill.installations.map((inst) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                inst.agentSlug,
                                style: TextStyle(
                                    fontSize: 10, color: primary),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),

        // --- Installation Guide Modal ---
        if (_guideAgent != null)
          _InstallGuideModal(
            agent: _guideAgent!,
            onClose: () => setState(() => _guideAgent = null),
          ),
      ],
    );
  }
}

// --- Sub-widgets ---

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
                : _hovered
                    ? onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? primary.withValues(alpha: 0.3)
                  : onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: widget.selected
                  ? primary
                  : onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final AgentConfig agent;
  final int skillCount;
  final VoidCallback? onTap;

  const _AgentCard({
    required this.agent,
    required this.skillCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: 200,
      child: InteractiveGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 20, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    agent.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: agent.detected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              agent.detected
                  ? l.t('dashboard.skillCount', {
                      'count': '$skillCount',
                    })
                  : l.t('dashboard.notInstalled'),
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (!agent.detected) ...[
              const SizedBox(height: 8),
              Text(
                l.t('dashboard.installationGuide'),
                style: TextStyle(
                  fontSize: 11,
                  color: primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal dialog showing installation guide for an undetected agent.
class _InstallGuideModal extends StatelessWidget {
  final AgentConfig agent;
  final VoidCallback onClose;

  const _InstallGuideModal({
    required this.agent,
    required this.onClose,
  });

  String _sourceLabel(AppLocalizations l) {
    switch (agent.installSourceLabel) {
      case 'official-docs':
        return l.t('dashboard.sourceOfficialDocs');
      case 'official-help-center':
        return l.t('dashboard.sourceOfficialHelpCenter');
      case 'official-readme':
        return l.t('dashboard.sourceOfficialReadme');
      case 'official-marketplace':
        return l.t('dashboard.sourceOfficialMarketplace');
      case 'homebrew-cask':
        return l.t('dashboard.sourceHomebrewCask');
      default:
        return l.t('dashboard.sourceUnspecified');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping modal
            child: Container(
              width: 520,
              constraints: const BoxConstraints(maxHeight: 600),
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ??
                    Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.t('dashboard.installGuideTitle', {
                              'name': agent.name,
                            }),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Source
                    Row(
                      children: [
                        Text(
                          '${l.t('dashboard.source')}: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _sourceLabel(l),
                            style: TextStyle(
                                fontSize: 12, color: primary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Text(
                      l.t('dashboard.diagnoseTip'),
                      style: TextStyle(
                        fontSize: 13,
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Version check
                    if (agent.cliCommand != null)
                      _CommandBlock(
                        label: l.t('dashboard.versionCheck'),
                        command: '${agent.cliCommand} --version',
                      ),

                    // PATH lookup
                    if (agent.cliCommand != null)
                      _CommandBlock(
                        label: l.t('dashboard.pathLookup'),
                        command: 'which ${agent.cliCommand}',
                      ),

                    // Install command
                    if (agent.installCommand != null)
                      _CommandBlock(
                        label: l.t('dashboard.installCommand'),
                        command: agent.installCommand!,
                      ),

                    const SizedBox(height: 12),

                    // Open docs button
                    if (agent.installDocsUrl != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          launchUrl(Uri.parse(agent.installDocsUrl!));
                        },
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: Text(l.t('dashboard.openDocs')),
                      ),

                    const SizedBox(height: 20),

                    // Expected paths
                    Text(
                      l.t('dashboard.expectedPaths'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...agent.globalPaths.map((path) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined,
                                  size: 14,
                                  color:
                                      onSurface.withValues(alpha: 0.4)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  path,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: onSurface
                                        .withValues(alpha: 0.7),
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandBlock extends StatelessWidget {
  final String label;
  final String command;

  const _CommandBlock({
    required this.label,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    command,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 14,
                      color: onSurface.withValues(alpha: 0.4)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: command));
                  },
                  tooltip: AppLocalizations.of(context).t('dashboard.copy'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
