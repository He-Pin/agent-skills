// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:agent_skills/models/agent_config.dart';
import 'package:agent_skills/models/app_settings.dart';
import 'package:agent_skills/models/marketplace_skill.dart';
import 'package:agent_skills/models/skill.dart';
import 'package:agent_skills/models/skill_repo.dart';
import 'package:agent_skills/services/agent_service.dart';
import 'package:agent_skills/services/marketplace_service.dart';
import 'package:agent_skills/services/repo_service.dart';
import 'package:agent_skills/services/settings_service.dart';
import 'package:agent_skills/services/skill_service.dart';
import 'package:flutter/material.dart';
import 'package:watcher/watcher.dart';

/// Central state provider for the entire application.
///
/// Manages agents, skills, marketplace data, repos, settings, and theme.
/// Uses ChangeNotifier for reactive UI updates (replaces React Query).
class AppProvider extends ChangeNotifier {
  // Services
  final AgentService _agentService = AgentService();
  late final SkillService _skillService = SkillService(_agentService);
  final MarketplaceService _marketplaceService = MarketplaceService();
  late final RepoService _repoService =
      RepoService(_agentService, _skillService);
  final SettingsService _settingsService = SettingsService();

  // State
  List<AgentConfig> _agents = [];
  List<Skill> _skills = [];
  List<SkillRepo> _repos = [];
  AppSettings _settings = AppSettings();
  bool _isLoading = true;
  String? _error;

  // Marketplace state
  List<MarketplaceSkill> _marketplaceSkills = [];
  bool _isMarketplaceLoading = false;
  String? _marketplaceError;
  String _marketplaceSource = 'skills.sh';
  String _marketplaceSort = 'all-time';

  // File watcher
  StreamSubscription<WatchEvent>? _watcherSubscription;

  // Getters
  List<AgentConfig> get agents => _agents;
  List<AgentConfig> get detectedAgents =>
      _agents.where((a) => a.detected).toList();
  List<Skill> get skills => _skills;
  List<SkillRepo> get repos => _repos;
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MarketplaceSkill> get marketplaceSkills => _marketplaceSkills;
  bool get isMarketplaceLoading => _isMarketplaceLoading;
  String? get marketplaceError => _marketplaceError;
  String get marketplaceSource => _marketplaceSource;
  String get marketplaceSort => _marketplaceSort;

  /// Initialize: load settings, detect agents, scan skills.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _settingsService.readSettings();
      _agents = await _agentService.detectAgents();
      _skills = await _skillService.scanAllSkills(_agents);
      _repos = await _repoService.listSkillRepos();
      _error = null;

      // Start file watcher for skill directories
      _startFileWatcher();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh agents and skills data.
  Future<void> refresh() async {
    try {
      _agents = await _agentService.detectAgents();
      _skills = await _skillService.scanAllSkills(_agents);
      _repos = await _repoService.listSkillRepos();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // --- Agent Operations ---

  /// Get skills for a specific agent.
  List<Skill> skillsForAgent(String agentSlug) {
    return _skills
        .where((s) => s.installations.any((i) => i.agentSlug == agentSlug))
        .toList();
  }

  // --- Skill Operations ---

  /// Read SKILL.md content.
  Future<String> readSkillContent(String skillPath) async {
    return _skillService.readSkillContent(skillPath);
  }

  /// Write SKILL.md content.
  Future<void> writeSkillContent(String skillPath, String content) async {
    await _skillService.writeSkillContent(skillPath, content);
    await refresh();
  }

  /// Uninstall skill from a specific agent.
  Future<void> uninstallSkill(String skillPath, String agentSlug) async {
    await _skillService.uninstallSkill(skillPath, agentSlug, _agents);
    await refresh();
  }

  /// Uninstall skill from all agents.
  Future<void> uninstallAll(String skillId) async {
    await _skillService.uninstallAll(skillId, _skills);
    await refresh();
  }

  /// Sync skill to additional agents.
  Future<void> syncSkill(
    String canonicalPath,
    List<String> targetAgentSlugs,
  ) async {
    await _skillService.syncSkill(canonicalPath, targetAgentSlugs, _agents);
    await refresh();
  }

  // --- Marketplace Operations ---

  void setMarketplaceSource(String source) {
    _marketplaceSource = source;
    _marketplaceSort = source == 'skills.sh' ? 'all-time' : 'default';
    notifyListeners();
    fetchMarketplace();
  }

  void setMarketplaceSort(String sort) {
    _marketplaceSort = sort;
    notifyListeners();
    fetchMarketplace();
  }

  Future<void> fetchMarketplace() async {
    _isMarketplaceLoading = true;
    _marketplaceError = null;
    notifyListeners();

    try {
      if (_marketplaceSource == 'skills.sh') {
        _marketplaceSkills = await _marketplaceService.fetchSkillsSh(
          sort: _marketplaceSort,
        );
      } else {
        _marketplaceSkills = await _marketplaceService.fetchClawHub(
          sort: _marketplaceSort,
        );
      }
    } catch (e) {
      _marketplaceError = e.toString();
    }

    _isMarketplaceLoading = false;
    notifyListeners();
  }

  Future<void> searchMarketplace(String query) async {
    if (query.isEmpty) {
      await fetchMarketplace();
      return;
    }

    _isMarketplaceLoading = true;
    _marketplaceError = null;
    notifyListeners();

    try {
      _marketplaceSkills = await _marketplaceService.searchMarketplace(
        query,
        _marketplaceSource,
      );
    } catch (e) {
      _marketplaceError = e.toString();
    }

    _isMarketplaceLoading = false;
    notifyListeners();
  }

  Future<String> fetchRemoteSkillContent(
    String repoUrl, {
    String? skillName,
  }) async {
    return _marketplaceService.fetchRemoteSkillContent(
      repoUrl,
      skillName: skillName,
    );
  }

  /// Install a marketplace skill to target agents.
  Future<void> installFromMarketplace(
    MarketplaceSkill skill,
    List<String> targetAgentSlugs,
  ) async {
    if (skill.repository == null || skill.repository!.isEmpty) return;

    // Check if already installed locally - if so, just sync
    final existing =
        _skills.where((s) => s.name.toLowerCase() == skill.name.toLowerCase());
    if (existing.isNotEmpty) {
      await syncSkill(existing.first.canonicalPath, targetAgentSlugs);
      return;
    }

    // Clone and install
    final repo = await _repoService.addSkillRepo(skill.repository!);
    final repoSkills = await _repoService.listRepoSkills(repo.id);
    if (repoSkills.isNotEmpty) {
      await _repoService.installRepoSkill(
        repo.id,
        repoSkills.first.id,
        targetAgentSlugs,
        _agents,
      );
    }

    await refresh();
  }

  void clearMarketplaceCache() {
    _marketplaceService.clearCache();
    notifyListeners();
  }

  // --- Repo Operations ---

  Future<SkillRepo> addSkillRepo(
    String url, {
    void Function(String stage)? onProgress,
  }) async {
    final repo = await _repoService.addSkillRepo(url, onProgress: onProgress);
    _repos = await _repoService.listSkillRepos();
    notifyListeners();
    return repo;
  }

  Future<SkillRepo> addLocalDir(String path) async {
    final repo = await _repoService.addLocalDir(path);
    _repos = await _repoService.listSkillRepos();
    notifyListeners();
    return repo;
  }

  Future<void> removeSkillRepo(String repoId) async {
    await _repoService.removeSkillRepo(repoId);
    _repos = await _repoService.listSkillRepos();
    notifyListeners();
  }

  Future<SkillRepo> syncSkillRepo(String repoId) async {
    final repo = await _repoService.syncSkillRepo(repoId);
    _repos = await _repoService.listSkillRepos();
    notifyListeners();
    return repo;
  }

  Future<List<Skill>> listRepoSkills(String repoId) async {
    return _repoService.listRepoSkills(repoId);
  }

  Future<void> installRepoSkill(
    String repoId,
    String skillId,
    List<String> targetAgentSlugs,
  ) async {
    await _repoService.installRepoSkill(
      repoId,
      skillId,
      targetAgentSlugs,
      _agents,
    );
    await refresh();
  }

  // --- Settings Operations ---

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _settingsService.writeSettings(newSettings);
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    _settings.theme = theme;
    await _settingsService.writeSettings(_settings);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _settings.language = language;
    await _settingsService.writeSettings(_settings);
    notifyListeners();
  }

  // --- File Watcher ---

  void _startFileWatcher() {
    _watcherSubscription?.cancel();

    for (final agent in _agents.where((a) => a.detected)) {
      for (final gp in agent.globalPaths) {
        final expanded = _agentService.expandHome(gp);
        try {
          final watcher = DirectoryWatcher(expanded);
          _watcherSubscription = watcher.events.listen((_) {
            // Debounce: wait a moment then refresh
            Future.delayed(const Duration(milliseconds: 500), () {
              refresh();
            });
          });
        } catch (_) {
          // Directory might not exist yet
        }
      }
    }
  }

  @override
  void dispose() {
    _watcherSubscription?.cancel();
    super.dispose();
  }
}
