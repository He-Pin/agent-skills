// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:agent_skills/i18n/app_localizations.dart';
import 'package:agent_skills/models/skill.dart';
import 'package:agent_skills/providers/app_provider.dart';
import 'package:agent_skills/widgets/glass_panel.dart';
import 'package:agent_skills/widgets/toast_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Multi-step import wizard for adding skill sources.
///
/// Steps:
/// 1. Source: Enter Git URL or select local folder
/// 2. Indexing: Show progress (cloning/scanning)
/// 3. Skills: Select which skills to import
/// 4. Agents: Select target agents
/// 5. Installing: Progress bar
///
/// Replaces ImportWizard.tsx from the React app.
class ImportWizard extends StatefulWidget {
  final String mode; // 'git' or 'local'
  final VoidCallback onClose;

  const ImportWizard({
    super.key,
    required this.mode,
    required this.onClose,
  });

  @override
  State<ImportWizard> createState() => _ImportWizardState();
}

class _ImportWizardState extends State<ImportWizard> {
  int _step = 0; // 0=source, 1=indexing, 2=skills, 3=agents, 4=installing
  final TextEditingController _urlController = TextEditingController();
  String _progressStage = '';
  String? _error;
  List<Skill> _repoSkills = [];
  Set<String> _selectedSkillIds = {};
  Set<String> _selectedAgentSlugs = {};
  String? _repoId;
  int _installDone = 0;
  int _installTotal = 0;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'local') {
      _pickLocalFolder();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _step == 1 || _step == 4 ? null : widget.onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing
            child: Container(
              width: 500,
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
              padding: const EdgeInsets.all(24),
              child: _buildStep(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildSourceStep(context);
      case 1:
        return _buildIndexingStep(context);
      case 2:
        return _buildSkillsStep(context);
      case 3:
        return _buildAgentsStep(context);
      case 4:
        return _buildInstallingStep(context);
      default:
        return const SizedBox();
    }
  }

  Widget _buildSourceStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.t('repos.importRepo'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: widget.onClose,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l.t('repos.importDescription'),
          style: TextStyle(
            fontSize: 13,
            color: onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: 'https://github.com/user/skills-repo.git',
            prefixIcon: const Icon(Icons.link, size: 18),
          ),
          onSubmitted: (_) => _startImport(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onClose,
              child: Text(l.t('repos.cancel')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _urlController.text.isNotEmpty
                  ? _startImport
                  : null,
              child: Text(l.t('repos.add')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIndexingStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    String stageText;
    switch (_progressStage) {
      case 'cloning':
        stageText = l.t('repos.cloning');
        break;
      case 'scanning':
        stageText = l.t('repos.scanning');
        break;
      case 'saving':
        stageText = l.t('repos.savingConfig');
        break;
      default:
        stageText = l.t('repos.cloning');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          stageText,
          style: TextStyle(
            fontSize: 14,
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSkillsStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l.t('repos.selectSkills'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              l.t('repos.skillsFound', {
                'count': '${_repoSkills.length}',
              }),
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() =>
                  _selectedSkillIds =
                      _repoSkills.map((s) => s.id).toSet()),
              child: Text(l.t('repos.selectAll'),
                  style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _selectedSkillIds.clear()),
              child: Text(l.t('repos.deselectAll'),
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_repoSkills.isEmpty)
          Text(
            l.t('repos.noSkillsFound'),
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.4),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _repoSkills.length,
              itemBuilder: (context, index) {
                final skill = _repoSkills[index];
                final isSelected =
                    _selectedSkillIds.contains(skill.id);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedSkillIds.add(skill.id);
                      } else {
                        _selectedSkillIds.remove(skill.id);
                      }
                    });
                  },
                  title: Text(skill.name,
                      style: const TextStyle(fontSize: 13)),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onClose,
              child: Text(l.t('repos.cancel')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _selectedSkillIds.isNotEmpty
                  ? () => setState(() => _step = 3)
                  : null,
              child: Text(l.t('repos.next', {
                'count': '${_selectedSkillIds.length}',
              })),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgentsStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.read<AppProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.t('repos.selectAgents'),
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (provider.detectedAgents.isEmpty)
          Text(l.t('repos.noAgentsDetected'))
        else
          ...provider.detectedAgents.map((agent) {
            final isSelected =
                _selectedAgentSlugs.contains(agent.slug);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedAgentSlugs.add(agent.slug);
                  } else {
                    _selectedAgentSlugs.remove(agent.slug);
                  }
                });
              },
              title: Text(agent.name,
                  style: const TextStyle(fontSize: 13)),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 2),
              child: Text(l.t('repos.back')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _selectedAgentSlugs.isNotEmpty
                  ? _startInstalling
                  : null,
              child: Text(l.t('repos.installCount', {
                'count': '${_selectedSkillIds.length}',
              })),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstallingStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: _installTotal > 0
              ? _installDone / _installTotal
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          l.t('repos.installingProgress', {
            'done': '$_installDone',
            'total': '$_installTotal',
          }),
          style: TextStyle(
            fontSize: 13,
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _pickLocalFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        setState(() {
          _step = 1;
          _progressStage = 'scanning';
        });

        final provider = context.read<AppProvider>();
        final repo = await provider.addLocalDir(result);
        _repoId = repo.id;

        final skills = await provider.listRepoSkills(repo.id);
        setState(() {
          _repoSkills = skills;
          _selectedSkillIds = skills.map((s) => s.id).toSet();
          _step = 2;
        });
      } else {
        widget.onClose();
      }
    } catch (e) {
      ToastManager().showError(
          AppLocalizations.of(context).t('common.importFolderFailed'));
      widget.onClose();
    }
  }

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _step = 1;
      _error = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final repo = await provider.addSkillRepo(
        url,
        onProgress: (stage) {
          if (mounted) {
            setState(() => _progressStage = stage);
          }
        },
      );
      _repoId = repo.id;

      final skills = await provider.listRepoSkills(repo.id);
      if (mounted) {
        setState(() {
          _repoSkills = skills;
          _selectedSkillIds = skills.map((s) => s.id).toSet();
          _step = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = 0;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _startInstalling() async {
    setState(() {
      _step = 4;
      _installDone = 0;
      _installTotal = _selectedSkillIds.length;
    });

    final provider = context.read<AppProvider>();
    for (final skillId in _selectedSkillIds) {
      try {
        await provider.installRepoSkill(
          _repoId!,
          skillId,
          _selectedAgentSlugs.toList(),
        );
      } catch (_) {
        // Continue with remaining skills on error
      }
      if (mounted) {
        setState(() => _installDone++);
      }
    }

    // Done - close wizard
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      widget.onClose();
    }
  }
}
