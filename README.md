# vibe-config

AI-assisted development environment settings for Claude Code and Kiro.

## Quick Start

```bash
# Run sync script (clones repo if needed, then syncs)
#   - claude/ -> ~/.claude/
#   - kiro/   -> ~/.kiro/
bash -c "$(curl -fsSL nalbam.github.io/vibe-config/sync.sh)"

# Or if already cloned
./sync.sh
```

### Options

```bash
./sync.sh        # Sync all changes (default)
./sync.sh -n     # Dry-run mode (show changes only)
./sync.sh -h     # Show help
```

## Directory Structure

```
vibe-config/
├── sync.sh                   # Sync script (clone/pull + sync)
│
├── claude/                   # Claude Code settings -> ~/.claude/
│   ├── CLAUDE.md             # Global Claude Code instructions
│   ├── settings.json         # Permissions, hooks, status line config
│   ├── statusline.py         # Custom status line script
│   ├── agents/               # Custom agent definitions
│   │   ├── architect.md      # System design and architecture
│   │   ├── builder.md        # Build error resolution
│   │   ├── code-reviewer.md  # Code review specialist
│   │   ├── debugger.md       # Debugging and error resolution
│   │   ├── doc-writer.md     # Documentation specialist
│   │   ├── planner.md        # Implementation planning (Opus)
│   │   ├── refactorer.md     # Code refactoring
│   │   └── test-writer.md    # Test generation
│   ├── hooks/                # Automated workflow hooks
│   │   └── vibemon.py        # Send status to Desktop app / ESP32
│   ├── rules/                # Always-follow guidelines
│   │   ├── coding-style.md   # Immutability, file organization
│   │   ├── git-workflow.md   # Commit format, PR process
│   │   ├── language.md       # Response language (Korean)
│   │   ├── patterns.md       # API formats, common patterns
│   │   ├── performance.md    # Model selection strategy
│   │   ├── security.md       # Security best practices
│   │   └── testing.md        # TDD workflow, 80% coverage
│   └── skills/               # User-invokable skills (/skill-name)
│       ├── commit/           # Create git commit with conventional format
│       ├── commit-push/      # Create git commit and push to remote
│       ├── context-init/     # Initialize and save project context
│       ├── context-load/     # Load saved project context
│       ├── code-audit/       # Deep code audit and analysis
│       ├── docs-sync/        # Documentation sync and gap analysis
│       ├── pr-create/        # Create PR with proper format
│       ├── resolve-coderabbit/ # Resolve CodeRabbit review comments
│       └── validate/         # Run lint, typecheck, tests
│
└── kiro/                     # Kiro settings -> ~/.kiro/
    ├── agents/               # Agent definitions
    │   └── default.json      # Default agent with vibemon hooks
    └── hooks/                # Kiro-specific hooks
        └── vibemon.py        # Send status to Desktop app / ESP32
```

## Features

### Terminal Session Support

The vibemon tracks terminal sessions for multi-window setups:

| Terminal | Environment Variable | ID Format |
|----------|---------------------|-----------|
| iTerm2 | `ITERM_SESSION_ID` | `iterm2:w0t4p0:UUID` |
| Ghostty | `GHOSTTY_PID` | `ghostty:PID` |

This allows the Desktop App to distinguish between multiple Claude Code sessions.

### Custom Agents

Specialized agents for delegated tasks:

| Agent | Purpose |
|-------|---------|
| `planner` | Implementation planning with detailed steps (Opus) |
| `architect` | System design and architecture decisions |
| `builder` | Build, lint, typecheck with auto-fix |
| `code-reviewer` | Code review for quality and security |
| `test-writer` | Test generation specialist |
| `refactorer` | Code refactoring without behavior change |
| `doc-writer` | Documentation updates |
| `debugger` | Debugging and error resolution |

### Hooks

Automated quality checks and workflow enforcement:

| Event | Script | Description |
|-------|--------|-------------|
| SessionStart | vibemon.py | Initialize monitor status |
| UserPromptSubmit | vibemon.py | Update monitor (thinking state) |
| PreToolUse | vibemon.py | Update monitor (working state) |
| PreCompact | vibemon.py | Update monitor (compacting state) |
| Notification | vibemon.py | Update monitor (notification state) |
| SubagentStart | vibemon.py | Update monitor (working state) |
| SessionEnd | vibemon.py | Update monitor (done state) |
| Stop | vibemon.py | Update monitor (done state) |

### Kiro Hooks

Kiro IDE/CLI uses different hook events:

| Kiro Event | State | Description |
|------------|-------|-------------|
| `agentSpawn` | start | Agent initialized |
| `promptSubmit` | thinking | Processing user input |
| `userPromptSubmit` | thinking | User prompt submitted |
| `preToolUse` | working | Executing tools |
| `fileCreated` | working | File created |
| `fileEdited` | working | File edited |
| `fileDeleted` | working | File deleted |
| `preCompact` | packing | Context compaction in progress |
| `agentStop` | done | Agent stopped |
| `stop` | done | Session stopped |

Note: Kiro's `vibemon.py` supports CLI commands: `--lock`, `--unlock`, `--status`, `--lock-mode`, `--reboot`.

### Skills

User-invokable via `/skill-name`:

```bash
/commit            # Create git commit with conventional format
/commit-push       # Create git commit and push to remote
/pr-create         # Create pull request with proper format
/code-audit        # Deep code audit and analysis
/validate          # Run lint, typecheck, tests with auto-fix
/docs-sync         # Analyze and update documentation
/context-init      # Initialize and save project context
/context-load      # Load saved project context
/resolve-coderabbit  # Resolve CodeRabbit review comments
```

### Vibe Monitor

Display Claude Code and Kiro status in real-time. Supports Claude Code, Kiro IDE, and Kiro CLI.

| Target | Description |
|--------|-------------|
| **Desktop App** | Frameless Electron app (macOS) on `localhost:19280` |
| **ESP32 Device** | ESP32-C6-LCD-1.47 via USB Serial or HTTP |

**Monitor States:**

| State | Trigger | Description |
|-------|---------|-------------|
| `start` | SessionStart | Session initialized |
| `thinking` | UserPromptSubmit | Processing user input |
| `planning` | UserPromptSubmit (plan mode) | Planning mode active |
| `working` | PreToolUse | Executing tools |
| `packing` | PreCompact | Context compaction in progress |
| `done` | Stop | Task completed |
| `notification` | Notification | Waiting for user input |

**Payload Structure:**

```json
{
  "state": "working",
  "tool": "Edit",
  "project": "my-project",
  "model": "Claude Opus 4",
  "memory": 62,
  "character": "clawd",
  "terminalId": "iterm2:w0t4p0:UUID"
}
```

| Field | Description |
|-------|-------------|
| `character` | `clawd` for Claude Code, `kiro` for Kiro |
| `terminalId` | Terminal session identifier (iTerm2/Ghostty) |

**Cache Limit:** The statusline cache keeps metadata for the 10 most recent projects.

See [vibemon](https://github.com/nalbam/vibemon) for Desktop app and ESP32 firmware.

## Configuration

### Claude Code Settings (`settings.json`)

| Setting | Value | Description |
|---------|-------|-------------|
| `model` | `opus` | Default Claude model |
| `cleanupPeriodDays` | `3650` | Conversation cleanup period (10 years) |
| `MAX_THINKING_TOKENS` | `31999` | Extended thinking token limit |
| `statusLine` | `statusline.py` | Custom status line (see below) |

### Status Line Display

The custom status line shows real-time session information:

```
📂 project │ ✨ feature/xxx * │ 🤖 Opus 4 │ 📥 12.5K 📤 3.2K │ 💰 $0.45 │ ⏱️ 2m30s ⏳ 17:00 │ +42 -15 │ 🧠 ━━━━━━╌╌╌╌ 62%
```

| Icon | Description |
|------|-------------|
| 📂 | Current project directory |
| 🌿/✨/🐛/etc | Git branch with type-specific emoji (asterisk if uncommitted changes) |
| 🤖 | Current Claude model |
| 📥/📤 | Input/output token usage |
| 💰 | Session cost in USD |
| ⏱️ | Session duration |
| ⏳ | Token reset time in local clock (5h rolling window, color-coded) |
| +/- | Lines added/removed |
| 🧠 | Context window usage with progress bar (green/yellow/red) |

### Git Branch Emojis

The status line shows branch-specific emojis:

| Branch Type | Emoji | Example |
|-------------|-------|---------|
| main/master | 🌿 | `main`, `master` |
| develop | 🌱 | `develop`, `dev`, `development` |
| feature | ✨ | `feature/xxx`, `feat/xxx` |
| fix/bugfix | 🐛 | `fix/xxx`, `bugfix/xxx` |
| hotfix | 🔥 | `hotfix/xxx` |
| release | 📦 | `release/xxx` |
| refactor | ♻️ | `refactor/xxx` |
| chore | 🧹 | `chore/xxx` |
| docs | 📝 | `docs/xxx`, `doc/xxx` |
| test | 🧪 | `test/xxx`, `experiment/xxx`, `exp/xxx` |

### Enabled Plugins

- `context7` - Up-to-date library documentation
- `superpowers` - Advanced skills and workflows

### VibeMon Config (`~/.vibemon/config.json`)

```json
{
  "cache_path": "~/.vibemon/cache/statusline.json",
  "auto_launch": false,
  "http_urls": ["http://127.0.0.1:19280"],
  "serial_port": "/dev/cu.usbmodem*",
  "vibemon_url": "https://vibemon.example.com",
  "vibemon_token": "your-token",
  "token_reset_hours": 5
}
```

| Key | Default | Description |
|-----|---------|-------------|
| `token_reset_hours` | `5` | Token reset window in hours. `0` to disable (Enterprise) |
| `cache_path` | `~/.vibemon/cache/statusline.json` | Cache file path |
| `auto_launch` | `false` | Auto-launch Desktop App |
| `http_urls` | - | HTTP target URLs (array) |
| `serial_port` | - | USB Serial port (wildcards supported) |
| `vibemon_url` | - | VibeMon server URL |
| `vibemon_token` | - | VibeMon auth token |

### Environment Variables

Create `~/.claude/.env.local` for local settings:

```bash
# Debug mode (1: enable, 0: disable)
# DEBUG=1

# Vibe Monitor
VIBEMON_CACHE_PATH=~/.vibemon/cache/statusline.json  # Cache file path
VIBEMON_AUTO_LAUNCH=0                        # Auto-launch Desktop App (0: disabled)
VIBEMON_HTTP_URLS=http://127.0.0.1:19280,http://192.168.0.185  # HTTP URLs (comma-separated)
VIBEMON_SERIAL_PORT=/dev/cu.usbmodem*        # USB Serial port (wildcards supported)
VIBEMON_TOKEN_RESET_HOURS=5                  # Token reset window hours (0: disable)

# VibeMon API
# VIBEMON_URL=https://vibemon.example.com   # VibeMon server URL
# VIBEMON_TOKEN=your-token                  # VibeMon auth token
```

> **Note:** `~/.vibemon/config.json` settings take precedence. Environment variables are used as fallback.

### Vibe Monitor CLI

The `vibemon.py` script supports CLI commands for manual control:

```bash
# Lock monitor to a specific project
python3 ~/.claude/hooks/vibemon.py --lock [project-name]

# Unlock monitor
python3 ~/.claude/hooks/vibemon.py --unlock

# Get current status
python3 ~/.claude/hooks/vibemon.py --status

# Get/set lock mode (first-project or on-thinking)
python3 ~/.claude/hooks/vibemon.py --lock-mode
python3 ~/.claude/hooks/vibemon.py --lock-mode first-project

# Reboot ESP32 device (ESP32 only, not Desktop App)
python3 ~/.claude/hooks/vibemon.py --reboot
```

## Related Projects

- [vibemon](https://github.com/nalbam/vibemon) - ESP32 status display for Claude Code
- [dotfiles](https://github.com/nalbam/dotfiles) - Development environment setup

## License

MIT
