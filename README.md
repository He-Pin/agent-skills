<h1 align="center">AgentSkills</h1>

<p align="center">
  A cross-platform desktop app for managing AI agent skills.<br>
  Browse, install, sync, and edit skills across 13 agents from a single interface.
</p>

<p align="center">
  <a href="https://github.com/chrlsio/agent-skills/releases"><img src="https://img.shields.io/github/v/release/chrlsio/agent-skills?style=flat-square" alt="Release"></a>
  <a href="https://github.com/chrlsio/agent-skills/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"></a>
  <a href="https://github.com/chrlsio/agent-skills/stargazers"><img src="https://img.shields.io/github/stars/chrlsio/agent-skills?style=flat-square" alt="Stars"></a>
</p>

<p align="center">
  <a href="./README.zh-CN.md">简体中文</a> |
    <strong>English</strong>
</p>

---

## Supported AI Tools

- Claude Code
- Cursor
- Codex
- Gemini CLI
- GitHub Copilot CLI
- Kiro
- OpenCode
- Antigravity
- CodeBuddy
- OpenClaw
- Trae
- Windsurf
- Cline

## Features

- **Dashboard** — See which agents are installed, how many skills each has
- **Skills Manager** — View, edit, uninstall, and sync skills across agents
- **Marketplace** — Browse and install skills from [skills.sh](https://skills.sh) and [ClawHub](https://clawhub.ai)
- **Skill Editor** — Edit SKILL.md files directly in the app
- **File Watcher** — Auto-refreshes when skills change on disk
- **Cross-Agent Sync** — Install a skill to one agent, sync it to all others in one click
- **Glassmorphism UI** — Frosted glass panels with accent color theming
- **Internationalization** — English and Simplified Chinese support
- **Import Wizard** — Multi-step wizard for importing from Git repos or local directories
- **Keyboard Shortcuts** — ⌘K to search, and more

## Tech Stack

**Framework:** Flutter 3.32+ (pure Dart, no native dependencies)

**State Management:** Provider + ChangeNotifier

**UI Effects:** Glassmorphism via BackdropFilter (liquid_glass_renderer compatible on macOS)

**Platforms:** macOS (Universal: x64 + ARM64) · Windows (x64) · Linux (x64)

## Installation

### Download from Releases

Download the latest build for your platform from [GitHub Releases](https://github.com/chrlsio/agent-skills/releases):

- **macOS:** `agent_skills-macos-universal.zip` — Universal binary (Intel + Apple Silicon)
- **Windows:** `agent_skills-windows-x64.zip` — Extract and run `agent_skills.exe`
- **Linux:** `agent_skills-linux-x64.tar.gz` — Extract and run `./agent_skills`

### Troubleshooting

#### macOS says "App is damaged and can't be opened"?

Due to macOS security checks, apps downloaded outside the App Store may trigger this message.

```bash
sudo xattr -rd com.apple.quarantine "/path/to/AgentSkills.app"
```

## Getting Started (Development)

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.32+)
- Platform-specific dependencies:
  - **Linux:** `sudo apt install cmake ninja-build libgtk-3-dev pkg-config`
  - **macOS:** Xcode command-line tools
  - **Windows:** Visual Studio with C++ desktop development workload

### Development

```bash
# Get dependencies
flutter pub get

# Run in development (hot reload)
flutter run -d linux   # or -d macos, -d windows

# Analyze code
flutter analyze

# Run tests
flutter test
```

### Build

```bash
# Build release for current platform
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

### CI/CD

The GitHub Actions workflow (`.github/workflows/build.yml`) automatically builds for all platforms on push to `main`. Tag a release with `v*` to create a GitHub Release with all platform artifacts.

## Architecture

```
lib/
├── main.dart              # App entry point + window setup
├── models/                # Data models (AgentConfig, Skill, etc.)
├── services/              # Business logic (agents, skills, marketplace, repos, settings)
├── providers/             # State management (AppProvider)
├── pages/                 # Main pages (Dashboard, Skills, Marketplace, Settings)
├── widgets/               # Reusable widgets (GlassPanel, SearchInput, Toast, etc.)
├── theme/                 # Theme system with 6 accent color presets
├── i18n/                  # Internationalization (EN + ZH-CN)
└── utils/                 # Utility functions
```

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

## Community Link

- [LINUX DO](https://linux.do/)

## License

[MIT](./LICENSE)
