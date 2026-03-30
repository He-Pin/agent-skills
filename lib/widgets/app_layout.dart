// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:agent_skills/i18n/app_localizations.dart';
import 'package:agent_skills/providers/app_provider.dart';
import 'package:agent_skills/widgets/glass_panel.dart';
import 'package:agent_skills/widgets/import_wizard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Main app layout with a floating glass sidebar and content area.
///
/// Replaces Layout.tsx from the React app. Provides:
/// - Floating glass sidebar with navigation
/// - Import buttons (Git/Local)
/// - Agent shortcuts with skill counts
/// - Resizable sidebar width
class AppLayout extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigate;
  final Widget child;
  final String? agentFilter;
  final ValueChanged<String?>? onAgentFilterChanged;

  const AppLayout({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
    required this.child,
    this.agentFilter,
    this.onAgentFilterChanged,
  });

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  double _sidebarWidth = 240;
  bool _isResizing = false;
  bool _showImportWizard = false;
  String _importMode = 'git';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        Row(
          children: [
            // --- Sidebar ---
            Padding(
              padding: const EdgeInsets.all(12),
              child: GlassPanel(
                borderRadius: 20,
                width: _sidebarWidth,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Import buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SidebarButton(
                              icon: Icons.download_rounded,
                              label: l.t('repos.importRepo'),
                              compact: true,
                              onTap: () => setState(() {
                                _importMode = 'git';
                                _showImportWizard = true;
                              }),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _SidebarButton(
                              icon: Icons.folder_open_rounded,
                              label: l.t('repos.importLocal'),
                              compact: true,
                              onTap: () => setState(() {
                                _importMode = 'local';
                                _showImportWizard = true;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    const SizedBox(height: 8),

                    // Main navigation
                    _NavItem(
                      icon: Icons.dashboard_rounded,
                      label: l.t('sidebar.dashboard'),
                      selected: widget.selectedIndex == 0,
                      onTap: () => widget.onNavigate(0),
                    ),
                    _NavItem(
                      icon: Icons.auto_awesome_rounded,
                      label: l.t('sidebar.skills'),
                      selected: widget.selectedIndex == 1 &&
                          widget.agentFilter == null,
                      onTap: () {
                        widget.onAgentFilterChanged?.call(null);
                        widget.onNavigate(1);
                      },
                    ),
                    _NavItem(
                      icon: Icons.store_rounded,
                      label: l.t('sidebar.marketplace'),
                      selected: widget.selectedIndex == 2,
                      onTap: () => widget.onNavigate(2),
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    const SizedBox(height: 8),

                    // Agent shortcuts header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Text(
                        l.t('sidebar.agents'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Agent list (scrollable)
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: provider.detectedAgents.length,
                        itemBuilder: (context, index) {
                          final agent = provider.detectedAgents[index];
                          final skillCount =
                              provider.skillsForAgent(agent.slug).length;
                          return _NavItem(
                            icon: Icons.smart_toy_outlined,
                            label: agent.name,
                            badge: skillCount > 0 ? '$skillCount' : null,
                            selected: widget.selectedIndex == 1 &&
                                widget.agentFilter == agent.slug,
                            onTap: () {
                              widget.onAgentFilterChanged?.call(agent.slug);
                              widget.onNavigate(1);
                            },
                          );
                        },
                      ),
                    ),

                    const Divider(height: 1, indent: 12, endIndent: 12),
                    const SizedBox(height: 4),

                    // Settings
                    _NavItem(
                      icon: Icons.settings_rounded,
                      label: l.t('sidebar.settings'),
                      selected: widget.selectedIndex == 3,
                      onTap: () => widget.onNavigate(3),
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
                    _sidebarWidth =
                        (_sidebarWidth + d.delta.dx).clamp(180, 400);
                  });
                },
                onHorizontalDragEnd: (_) =>
                    setState(() => _isResizing = false),
                child: Container(
                  width: 6,
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 2,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _isResizing
                            ? primary.withValues(alpha: 0.6)
                            : Theme.of(context)
                                    .dividerTheme
                                    .color
                                    ?.withValues(alpha: 0.3) ??
                                Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- Main Content ---
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(top: 12, right: 12, bottom: 12),
                child: widget.child,
              ),
            ),
          ],
        ),

        // Import Wizard overlay
        if (_showImportWizard)
          ImportWizard(
            mode: _importMode,
            onClose: () => setState(() => _showImportWizard = false),
          ),
      ],
    );
  }
}

/// A single navigation item in the sidebar.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
    this.badge,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: widget.selected
                  ? primary.withValues(alpha: isDark ? 0.15 : 0.1)
                  : _hovered
                      ? onSurface.withValues(alpha: 0.04)
                      : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.selected
                      ? primary
                      : onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: widget.selected
                          ? primary
                          : onSurface.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact sidebar button for import actions.
class _SidebarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
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
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovered
                ? onSurface.withValues(alpha: 0.06)
                : onSurface.withValues(alpha: 0.03),
            border: Border.all(
              color: onSurface
                  .withValues(alpha: isDark ? 0.08 : 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: onSurface.withValues(alpha: 0.5),
              ),
              if (!widget.compact) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
