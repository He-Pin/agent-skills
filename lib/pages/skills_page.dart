// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:agent_skills/i18n/app_localizations.dart';
import 'package:agent_skills/models/skill.dart';
import 'package:agent_skills/providers/app_provider.dart';
import 'package:agent_skills/widgets/glass_panel.dart';
import 'package:agent_skills/widgets/search_input.dart';
import 'package:agent_skills/widgets/toast_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Skills Manager page - browse, manage, and edit installed skills.
///
/// Features a dual-pane layout with a resizable split:
/// - Left pane: filterable/searchable skill list
/// - Right pane: skill detail view with markdown, package info, and editor
///
/// Replaces SkillsManager.tsx from the React app.
class SkillsPage extends StatefulWidget {
  final String? agentFilter;

  const SkillsPage({super.key, this.agentFilter});

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  String _searchTerm = '';
  String? _selectedSkillId;
  bool _isEditing = false;
  String _editorContent = '';
  double _listWidth = 300;
  bool _isResizing = false;

  // Loaded skill content for detail view
  String? _skillContent;
  bool _isLoadingContent = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<AppProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Filter skills
    var skills = provider.skills.toList();
    if (widget.agentFilter != null) {
      skills = skills
          .where((s) => s.installations
              .any((i) => i.agentSlug == widget.agentFilter))
          .toList();
    }
    if (_searchTerm.isNotEmpty) {
      final term = _searchTerm.toLowerCase();
      skills = skills.where((s) {
        return s.name.toLowerCase().contains(term) ||
            s.id.toLowerCase().contains(term) ||
            (s.description?.toLowerCase().contains(term) ?? false);
      }).toList();
    }

    final selectedSkill = _selectedSkillId != null
        ? skills.where((s) => s.id == _selectedSkillId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Header with agent filter buttons ---
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterButton(
                  label: l.t('skills.filterAll'),
                  selected: widget.agentFilter == null,
                  onTap: () {
                    // Navigate up to clear agent filter - handled by parent
                  },
                ),
                const SizedBox(width: 6),
                ...provider.detectedAgents.map((agent) {
                  final count =
                      provider.skillsForAgent(agent.slug).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterButton(
                      label: '${agent.name} ($count)',
                      selected: widget.agentFilter == agent.slug,
                      onTap: () {
                        // Agent filter handled by parent layout
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // --- Dual pane layout ---
        Expanded(
          child: Row(
            children: [
              // --- Left Pane: Skill List ---
              SizedBox(
                width: _listWidth,
                child: GlassPanel(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SearchInput(
                        placeholder: l.t('skills.filterPlaceholder'),
                        onChanged: (v) => setState(() => _searchTerm = v),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: skills.isEmpty
                            ? Center(
                                child: Text(
                                  l.t('skills.noSkillsFound'),
                                  style: TextStyle(
                                    color: onSurface.withValues(alpha: 0.4),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: skills.length,
                                itemBuilder: (context, index) {
                                  final skill = skills[index];
                                  final isSelected =
                                      skill.id == _selectedSkillId;
                                  return InteractiveGlassCard(
                                    selected: isSelected,
                                    borderRadius: 10,
                                    padding: const EdgeInsets.all(10),
                                    onTap: () => _selectSkill(skill),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          skill.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? primary
                                                : onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (skill.description != null)
                                          Text(
                                            skill.description!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: onSurface
                                                  .withValues(alpha: 0.4),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          children:
                                              skill.installations.map((inst) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: primary
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                inst.agentSlug,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: primary),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
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
                          (_listWidth + d.delta.dx).clamp(200, 500);
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
                child: selectedSkill == null
                    ? Center(
                        child: Text(
                          l.t('skills.selectToView'),
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : _isEditing
                        ? _buildEditor(context, selectedSkill)
                        : _buildDetail(context, selectedSkill),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectSkill(Skill skill) async {
    setState(() {
      _selectedSkillId = skill.id;
      _isEditing = false;
      _isLoadingContent = true;
    });

    final provider = context.read<AppProvider>();
    try {
      final content = await provider.readSkillContent(skill.canonicalPath);
      if (mounted) {
        setState(() {
          _skillContent = content;
          _isLoadingContent = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _skillContent = null;
          _isLoadingContent = false;
        });
      }
    }
  }

  Widget _buildDetail(BuildContext context, Skill skill) {
    final l = AppLocalizations.of(context);
    final provider = context.read<AppProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Determine which agents don't have this skill yet
    final installedSlugs = skill.installedAgentSlugs;
    final missingAgents = provider.detectedAgents
        .where((a) => !installedSlugs.contains(a.slug))
        .toList();

    return GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          // Skill name + actions
          Row(
            children: [
              Expanded(
                child: Text(
                  skill.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              // Reveal in Finder
              Tooltip(
                message: l.t('skills.revealInFinder'),
                child: IconButton(
                  icon: Icon(Icons.folder_open,
                      size: 18,
                      color: onSurface.withValues(alpha: 0.5)),
                  onPressed: () {
                    launchUrl(Uri.file(skill.canonicalPath));
                  },
                ),
              ),
            ],
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
          _SectionTitle(title: l.t('skills.packageInfo')),
          _InfoRow(
            label: l.t('skills.id'),
            value: skill.id,
          ),
          _InfoRow(
            label: l.t('skills.scope'),
            value: skill.scope.type == SkillScopeType.sharedGlobal
                ? l.t('skills.scopeGlobal')
                : l.t('skills.scopeLocal', {
                    'name': skill.scope.agent ?? '',
                  }),
          ),

          const SizedBox(height: 16),

          // --- Agent Installations ---
          _SectionTitle(
            title: l.t('skills.agentsLabel', {
              'installed': '${skill.installations.length}',
              'total': '${provider.agents.length}',
            }),
          ),
          ...skill.installations.map((inst) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    inst.agentSlug,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (inst.isSymlink) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l.t('skills.symlink'),
                        style: TextStyle(
                          fontSize: 10,
                          color: onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      try {
                        await provider.uninstallSkill(
                            inst.path, inst.agentSlug);
                      } catch (_) {
                        ToastManager().showError(
                            l.t('skills.uninstallFailed'));
                      }
                    },
                    child: Text(
                      l.t('skills.uninstall'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // --- Actions ---
          _SectionTitle(title: l.t('skills.actions')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    _editorContent = _skillContent ?? '';
                  });
                },
                icon: const Icon(Icons.edit, size: 14),
                label: Text(l.t('skills.editSkillMd'),
                    style: const TextStyle(fontSize: 12)),
              ),
              if (missingAgents.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await provider.syncSkill(
                        skill.canonicalPath,
                        missingAgents.map((a) => a.slug).toList(),
                      );
                    } catch (_) {
                      ToastManager()
                          .showError(l.t('skills.syncFailed'));
                    }
                  },
                  icon: const Icon(Icons.sync, size: 14),
                  label: Text(
                    l.t('skills.syncTo', {
                      'names':
                          missingAgents.map((a) => a.name).join(', '),
                    }),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await provider.uninstallAll(skill.id);
                    setState(() => _selectedSkillId = null);
                  } catch (_) {
                    ToastManager()
                        .showError(l.t('skills.uninstallFailed'));
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 14),
                label: Text(l.t('skills.uninstallAll'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // --- Skill Content (Markdown) ---
          _SectionTitle(title: l.t('skills.skillContent')),
          if (_isLoadingContent)
            const Center(child: CircularProgressIndicator())
          else if (_skillContent != null && _skillContent!.isNotEmpty)
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
                data: _stripFrontmatter(_skillContent!),
                selectable: true,
              ),
            )
          else
            Text(
              l.t('skills.noContent'),
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context, Skill skill) {
    final l = AppLocalizations.of(context);
    final provider = context.read<AppProvider>();
    final primary = Theme.of(context).colorScheme.primary;

    return GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = false),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(l.t('skills.backToDetail')),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await provider.writeSkillContent(
                        skill.canonicalPath, _editorContent);
                    setState(() {
                      _skillContent = _editorContent;
                      _isEditing = false;
                    });
                  } catch (_) {
                    ToastManager()
                        .showError(l.t('skills.saveFailed'));
                  }
                },
                icon: const Icon(Icons.save, size: 16),
                label: Text(l.t('skills.save')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller:
                  TextEditingController(text: _editorContent),
              onChanged: (v) => _editorContent = v,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Strip YAML frontmatter from markdown content.
  String _stripFrontmatter(String content) {
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        return content.substring(endIndex + 3).trim();
      }
    }
    return content;
  }
}

class _FilterButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
