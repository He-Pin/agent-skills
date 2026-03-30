// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:agent_skills/models/agent_config.dart';

/// Service for loading and detecting AI agent configurations.
///
/// The original Tauri app loaded agent configs from TOML files at runtime.
/// Here we hardcode the 13 supported agents for simplicity and reliability
/// across all desktop platforms.
class AgentService {
  /// Returns the hardcoded list of all 13 supported agent configurations.
  List<AgentConfig> loadAgentConfigs() {
    return [
      AgentConfig(
        slug: 'claude-code',
        name: 'Claude Code',
        globalPaths: ['~/.claude/skills'],
        cliCommand: 'claude',
        installCommand: 'curl -fsSL https://claude.ai/install.sh | bash',
        installDocsUrl:
            'https://docs.anthropic.com/en/docs/claude-code/getting-started',
        installSourceLabel: 'official-docs',
      ),
      AgentConfig(
        slug: 'cursor',
        name: 'Cursor',
        globalPaths: ['~/.cursor/skills'],
        cliCommand: 'cursor',
        installCommand: 'curl https://cursor.com/install -fsS | bash',
        installDocsUrl: 'https://cursor.com/docs/cli/overview',
        installSourceLabel: 'official-docs',
      ),
      AgentConfig(
        slug: 'cline',
        name: 'Cline',
        globalPaths: ['~/.cline/skills'],
        cliCommand: 'cline',
        installCommand: 'code --install-extension saoudrizwan.claude-dev',
        installDocsUrl:
            'https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev',
        installSourceLabel: 'official-marketplace',
      ),
      AgentConfig(
        slug: 'windsurf',
        name: 'Windsurf',
        globalPaths: ['~/.codeium/windsurf/skills'],
        cliCommand: 'windsurf',
        installCommand: 'brew install --cask windsurf',
        installDocsUrl: 'https://formulae.brew.sh/cask/windsurf',
        installSourceLabel: 'homebrew-cask',
      ),
      AgentConfig(
        slug: 'copilot-cli',
        name: 'GitHub Copilot CLI',
        globalPaths: ['~/.copilot/skills'],
        cliCommand: 'copilot',
        installCommand: 'npm install -g @github/copilot',
        installDocsUrl:
            'https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-in-the-cli',
        installSourceLabel: 'official-docs',
      ),
      AgentConfig(
        slug: 'codex',
        name: 'Codex',
        globalPaths: ['~/.codex/skills'],
        cliCommand: 'codex',
        installCommand: 'npm install -g @openai/codex',
        installDocsUrl:
            'https://help.openai.com/en/articles/11096431-openai-codex-cli-getting-started',
        installSourceLabel: 'official-help-center',
      ),
      AgentConfig(
        slug: 'gemini-cli',
        name: 'Gemini CLI',
        globalPaths: ['~/.gemini/skills'],
        skillFormat: SkillFormat.geminiExtension,
        cliCommand: 'gemini',
        installCommand: 'npm install -g @google/gemini-cli',
        installDocsUrl:
            'https://google-gemini.github.io/gemini-cli/docs/get-started/',
        installSourceLabel: 'official-docs',
      ),
      AgentConfig(
        slug: 'trae',
        name: 'Trae',
        globalPaths: ['~/.trae/skills'],
        cliCommand: 'trae',
        installCommand: 'brew install --cask trae',
        installDocsUrl: 'https://formulae.brew.sh/cask/trae',
        installSourceLabel: 'homebrew-cask',
      ),
      AgentConfig(
        slug: 'opencode',
        name: 'OpenCode',
        globalPaths: ['~/.opencode/skills'],
        cliCommand: 'opencode',
        installCommand: 'curl -fsSL https://opencode.ai/install | bash',
        installDocsUrl: 'https://opencode.ai/docs/cli/',
        installSourceLabel: 'official-readme',
      ),
      AgentConfig(
        slug: 'openclaw',
        name: 'OpenClaw',
        globalPaths: ['~/.openclaw/skills'],
        cliCommand: 'openclaw',
        installCommand: 'npm install -g openclaw@latest',
        installDocsUrl: 'https://docs.openclaw.ai/start/getting-started',
        installSourceLabel: 'official-readme',
      ),
      AgentConfig(
        slug: 'antigravity',
        name: 'Antigravity',
        globalPaths: ['~/.antigravity/skills'],
        cliCommand: 'antigravity',
        installCommand: 'brew install --cask antigravity',
        installDocsUrl: 'https://formulae.brew.sh/cask/antigravity',
        installSourceLabel: 'homebrew-cask',
      ),
      AgentConfig(
        slug: 'kiro',
        name: 'Kiro',
        globalPaths: ['~/.kiro/skills'],
        cliCommand: 'kiro-cli',
        installCommand:
            'curl -fsSL https://cli.kiro.dev/install | bash',
        installDocsUrl: 'https://kiro.dev/docs/cli/',
        installSourceLabel: 'official-docs',
      ),
      AgentConfig(
        slug: 'codebuddy',
        name: 'CodeBuddy',
        globalPaths: ['~/.codebuddy/skills'],
        cliCommand: 'codebuddy',
        installCommand: 'npm install -g @tencent-ai/codebuddy-code',
        installDocsUrl: 'https://www.codebuddy.ai/docs/cli/installation',
        installSourceLabel: 'official-docs',
      ),
    ];
  }

  /// Expand ~ to user home directory.
  String expandHome(String path) {
    if (path.startsWith('~/') || path == '~') {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      return path.replaceFirst('~', home);
    }
    return path;
  }

  /// Detect which agents are installed on the system.
  /// Checks if any of the agent's global_paths exist or if the CLI command exists.
  Future<List<AgentConfig>> detectAgents() async {
    final configs = loadAgentConfigs();
    for (final config in configs) {
      config.detected = await _isAgentDetected(config);
    }
    return configs;
  }

  Future<bool> _isAgentDetected(AgentConfig config) async {
    // Check if any global path exists
    for (final p in config.globalPaths) {
      final expanded = expandHome(p);
      if (await Directory(expanded).exists()) {
        return true;
      }
    }
    // Fallback: check if CLI command exists via 'which' (Unix) or 'where' (Windows)
    if (config.cliCommand != null) {
      return await _commandExists(config.cliCommand!);
    }
    return false;
  }

  Future<bool> _commandExists(String command) async {
    try {
      final whichCmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(whichCmd, [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
