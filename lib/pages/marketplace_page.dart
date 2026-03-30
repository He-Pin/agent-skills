// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:agent_skills/i18n/app_localizations.dart';
import 'package:agent_skills/models/marketplace_skill.dart';
import 'package:agent_skills/providers/app_provider.dart';
import 'package:agent_skills/widgets/glass_panel.dart';
import 'package:agent_skills/widgets/search_input.dart';
import 'package:agent_skills/widgets/toast_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Marketplace page - browse and install skills from online sources.
///
/// Supports two marketplace sources: skills.sh and ClawHub.
/// Each source has its own sort options and search.
///
/// Replaces Marketplace.tsx from the React app.
class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  MarketplaceSkill? _selectedSkill;
  String? _remoteContent;
  bool _isLoadingContent = false;
  double _listWidth = 340;
  bool _isResizing = false;
  Set<String> _installingAgents = {};

  @override
  void initState() {
    super.initState();
    // Trigger initial marketplace fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMarketplace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<AppProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final source = provider.marketplaceSource;
    final sort = provider.marketplaceSort;

    // Sort options depend on source
    final sortOptions = source == 'skills.sh'
        ? [
            ('all-time', l.t('marketplace.sortAllTime')),
            ('trending', l.t('marketplace.sortTrending')),
            ('hot', l.t('marketplace.sortHot')),
          ]
        : [
            ('default', l.t('marketplace.sortDefault')),
            ('downloads', l.t('marketplace.sortDownloads')),
            ('stars', l.t('marketplace.sortStars')),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Source tabs + Sort options ---
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // Source tabs
              _SourceTab(
                label: 'skills.sh',
                selected: source == 'skills.sh',
                onTap: () => provider.setMarketplaceSource('skills.sh'),
              ),
              const SizedBox(width: 6),
              _SourceTab(
                label: 'ClawHub',
                selected: source == 'clawhub',
                onTap: () => provider.setMarketplaceSource('clawhub'),
              ),
              const SizedBox(width: 16),
              // Sort options
              ...sortOptions.map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _SortChip(
                    label: opt.$2,
                    selected: sort == opt.$1,
                    onTap: () => provider.setMarketplaceSort(opt.$1),
                  ),
                );
              }),
            ],
          ),
        ),

        // --- Dual pane layout ---
        Expanded(
          child: Row(
            children: [
              // --- Left Pane: Marketplace List ---
              SizedBox(
                width: _listWidth,
                child: GlassPanel(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SearchInput(
                        placeholder: l.t('marketplace.searchPlaceholder', {
                          'source': source,
                        }),
                        onChanged: (v) => provider.searchMarketplace(v),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildSkillList(context, provider),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Resize Handle ---
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) =>
                      setState(() => _isResizing = true),
                  onHorizontalDragUpdate: (d) {
                    setState(() {
                      _listWidth =
                          (_listWidth + d.delta.dx).clamp(250, 500);
                    });
                  },
                  onHorizontalDragEnd: (_) =>
                      setState(() => _isResizing = false),
                  child: Container(
                    width: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 2,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _isResizing
                              ? primary.withValues(alpha: 0.6)
                              : onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- Right Pane: Detail ---
              Expanded(
                child: _selectedSkill == null
                    ? Center(
                        child: Text(
                          l.t('marketplace.noSkillsFound'),
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : _buildDetail(context, _selectedSkill!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillList(BuildContext context, AppProvider provider) {
    final l = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;

    if (provider.isMarketplaceLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.marketplaceError != null) {
      return Center(
        child: Text(
          l.t('marketplace.failedToLoad', {
            'error': provider.marketplaceError!,
          }),
          style: TextStyle(color: onSurface.withValues(alpha: 0.5)),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (provider.marketplaceSkills.isEmpty) {
      return Center(
        child: Text(
          l.t('marketplace.noSkillsFound'),
          style: TextStyle(color: onSurface.withValues(alpha: 0.4)),
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.marketplaceSkills.length,
      itemBuilder: (context, index) {
        final skill = provider.marketplaceSkills[index];
        final isSelected = _selectedSkill?.name == skill.name;

        return InteractiveGlassCard(
          selected: isSelected,
          borderRadius: 10,
          padding: const EdgeInsets.all(12),
          onTap: () => _selectMarketplaceSkill(skill),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                skill.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? primary : onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (skill.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    skill.description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.4),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (skill.author != null)
                    Text(
                      skill.author!,
                      style: TextStyle(
                        fontSize: 10,
                        color: onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  const Spacer(),
                  if (skill.installs != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download,
                            size: 12,
                            color: onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 3),
                        Text(
                          '${skill.installs}',
                          style: TextStyle(
                            fontSize: 10,
                            color: onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetail(BuildContext context, MarketplaceSkill skill) {
    final l = AppLocalizations.of(context);
    final provider = context.read<AppProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Check which agents already have this skill installed
    final installedSkill = provider.skills
        .where((s) => s.name.toLowerCase() == skill.name.toLowerCase())
        .firstOrNull;
    final installedSlugs =
        installedSkill?.installedAgentSlugs ?? [];

    return GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          // Header
          Text(
            skill.name,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (skill.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                skill.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // --- Package Info ---
          _DetailSection(title: l.t('marketplace.packageInfo')),
          if (skill.repository != null)
            _DetailRow(
              label: l.t('marketplace.repository'),
              child: GestureDetector(
                onTap: () => launchUrl(Uri.parse(skill.repository!)),
                child: Text(
                  skill.repository!,
                  style: TextStyle(
                    fontSize: 12,
                    color: primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (skill.installs != null)
            _DetailRow(
              label: l.t('marketplace.installs'),
              child: Text('${skill.installs}',
                  style: const TextStyle(fontSize: 12)),
            ),

          const SizedBox(height: 16),

          // --- Install Section ---
          _DetailSection(
            title: l.t('marketplace.agentsLabel', {
              'installed': '${installedSlugs.length}',
              'total': '${provider.agents.length}',
            }),
          ),

          // Per-agent install buttons
          ...provider.detectedAgents.map((agent) {
            final isInstalled = installedSlugs.contains(agent.slug);
            final isInstalling =
                _installingAgents.contains(agent.slug);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isInstalled
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      agent.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (isInstalled)
                    Text(
                      l.t('marketplace.installed'),
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF22C55E),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: isInstalling
                          ? null
                          : () => _installForAgent(
                              skill, agent.slug),
                      child: Text(
                        isInstalling
                            ? l.t('marketplace.installing')
                            : l.t('marketplace.install'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          }),

          // Install All button
          if (provider.detectedAgents.any(
              (a) => !installedSlugs.contains(a.slug)))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: _installingAgents.isNotEmpty
                    ? null
                    : () => _installAll(skill),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(_installingAgents.isNotEmpty
                    ? l.t('marketplace.installing')
                    : l.t('marketplace.installAll')),
              ),
            ),

          const SizedBox(height: 16),

          // --- Actions ---
          _DetailSection(title: l.t('marketplace.actions')),
          Wrap(
            spacing: 8,
            children: [
              if (skill.repository != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse(skill.repository!)),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(l.t('marketplace.viewRepository'),
                      style: const TextStyle(fontSize: 12)),
                ),
              if (skill.source == 'skills.sh')
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'https://skills.sh/skills/${skill.slug ?? skill.name}')),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(l.t('marketplace.viewOnSkillsSh'),
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // --- Skill Content (Markdown from repo) ---
          _DetailSection(title: l.t('marketplace.skillContent')),
          if (_isLoadingContent)
            const Center(child: CircularProgressIndicator())
          else if (_remoteContent != null &&
              _remoteContent!.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: onSurface.withValues(alpha: 0.06),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: _remoteContent!,
                selectable: true,
              ),
            )
          else
            Text(
              skill.repository != null
                  ? l.t('marketplace.couldNotLoad')
                  : l.t('marketplace.noRepoUrl'),
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectMarketplaceSkill(MarketplaceSkill skill) async {
    setState(() {
      _selectedSkill = skill;
      _remoteContent = null;
      _isLoadingContent = true;
    });

    if (skill.repository != null) {
      try {
        final content = await context
            .read<AppProvider>()
            .fetchRemoteSkillContent(skill.repository!);
        if (mounted) {
          setState(() {
            _remoteContent = content;
            _isLoadingContent = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingContent = false);
        }
      }
    } else {
      setState(() => _isLoadingContent = false);
    }
  }

  Future<void> _installForAgent(
    MarketplaceSkill skill,
    String agentSlug,
  ) async {
    setState(() => _installingAgents.add(agentSlug));
    try {
      await context
          .read<AppProvider>()
          .installFromMarketplace(skill, [agentSlug]);
    } catch (_) {
      ToastManager().showError(
          AppLocalizations.of(context).t('marketplace.installFailed'));
    }
    if (mounted) {
      setState(() => _installingAgents.remove(agentSlug));
    }
  }

  Future<void> _installAll(MarketplaceSkill skill) async {
    final provider = context.read<AppProvider>();
    final allSlugs = provider.detectedAgents
        .where((a) => !provider.skills.any((s) =>
            s.name.toLowerCase() == skill.name.toLowerCase() &&
            s.installations.any((i) => i.agentSlug == a.slug)))
        .map((a) => a.slug)
        .toList();

    setState(() => _installingAgents.addAll(allSlugs));
    try {
      await provider.installFromMarketplace(skill, allSlugs);
    } catch (_) {
      ToastManager().showError(
          AppLocalizations.of(context).t('marketplace.installFailed'));
    }
    if (mounted) {
      setState(() => _installingAgents.clear());
    }
  }
}

class _SourceTab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SourceTab({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  State<_SourceTab> createState() => _SourceTabState();
}

class _SourceTabState extends State<_SourceTab> {
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
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? primary.withValues(alpha: 0.12)
                : _hovered
                    ? onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: widget.selected ? primary : onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  State<_SortChip> createState() => _SortChipState();
}

class _SortChipState extends State<_SortChip> {
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
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.selected
                ? primary.withValues(alpha: 0.1)
                : _hovered
                    ? onSurface.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: widget.selected
                  ? primary
                  : onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;

  const _DetailSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
