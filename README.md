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
./sync.sh        # Interactive mode (prompts for each change)
./sync.sh -y     # Auto-yes mode (sync all without prompts)
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
│   ├── .env.example          # Environment variables template
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
│   │   ├── vibe-monitor.py   # Send status to Desktop app / ESP32
│   │   └── notify.sh         # Multi-platform notifications
│   ├── rules/                # Always-follow guidelines
│   │   ├── coding-style.md   # Immutability, file organization
│   │   ├── git-workflow.md   # Commit format, PR process
│   │   ├── language.md       # Response language (Korean)
│   │   ├── patterns.md       # API formats, common patterns
│   │   ├── performance.md    # Model selection strategy
│   │   ├── security.md       # Security best practices
│   │   └── testing.md        # TDD workflow, 80% coverage
│   ├── skills/               # User-invokable skills (/skill-name)
│   │   ├── docs-sync/        # Documentation sync and gap analysis
│   │   ├── pr-create/        # Create PR with proper format
│   │   ├── validate/         # Run lint, typecheck, tests
│   │   ├── vibemon-lock/     # Lock vibe-monitor to current project
│   │   └── vibemon-mode/     # Change vibe-monitor lock mode
│   └── sounds/               # Audio notifications
│       ├── ding1.mp3
│       ├── ding2.mp3
│       └── ding3.mp3
│
└── kiro/                     # Kiro settings -> ~/.kiro/
    ├── .env.example          # Environment variables template
    ├── agents/               # Agent definitions
    │   └── default.json      # Default agent with vibe-monitor hooks
    └── hooks/                # Kiro-specific hooks
        ├── vibe-monitor.py   # Send status to Desktop app / ESP32
        └── *.kiro.hook       # Hook trigger files
```

## Features

### Terminal Session Support

The vibe-monitor tracks terminal sessions for multi-window setups:

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

**SessionStart:**
- `vibe-monitor.py` - Initialize monitor status

**UserPromptSubmit:**
- `vibe-monitor.py` - Update monitor (thinking state)

**PreToolUse:**
- `vibe-monitor.py` - Update monitor (working state)

**Stop:**
- `notify.sh` - Send completion notifications
- `vibe-monitor.py` - Update monitor (done state)

**Notification:**
- `notify.sh` - Send completion notifications
- `vibe-monitor.py` - Update monitor (notification state)

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
| `agentStop` | done | Agent stopped |
| `stop` | done | Session stopped |

Note: Kiro's `vibe-monitor.py` supports `--lock`, `--unlock`, `--status` but not `--lock-mode`.

### Skills

User-invokable via `/skill-name`:

```bash
/validate      # Run lint, typecheck, tests with auto-fix
/docs-sync     # Analyze and update documentation
/pr-create     # Create pull request with proper format
/vibemon-lock  # Lock vibe-monitor to current project
/vibemon-mode  # Change vibe-monitor lock mode
```

### Notification System

The `notify.sh` hook supports multiple platforms:
- **macOS**: Native notifications + audio alerts
- **WSL**: PowerShell beep notifications
- **ntfy.sh**: Push notifications (set `NTFY_TOPIC`)
- **Slack**: Webhook notifications (set `SLACK_WEBHOOK_URL`)

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
| `done` | Stop | Task completed |
| `notification` | Notification | Waiting for user input |

**Payload Structure:**

```json
{
  "state": "working",
  "tool": "Edit",
  "project": "my-project",
  "model": "Claude Opus 4",
  "memory": "62%",
  "character": "clawd",
  "terminalId": "iterm2:w0t4p0:UUID"
}
```

| Field | Description |
|-------|-------------|
| `character` | `clawd` for Claude Code, `kiro` for Kiro |
| `terminalId` | Terminal session identifier (iTerm2/Ghostty) |

**Cache Limit:** The statusline cache keeps metadata for the 10 most recent projects.

See [vibe-monitor](https://github.com/nalbam/vibe-monitor) for Desktop app and ESP32 firmware.

## Configuration

The `settings.json` file includes:

| Setting | Value | Description |
|---------|-------|-------------|
| `model` | `opus` | Default Claude model |
| `cleanupPeriodDays` | `3650` | Conversation cleanup period (10 years) |
| `MAX_THINKING_TOKENS` | `31999` | Extended thinking token limit |
| `statusLine` | `statusline.py` | Custom status line (see below) |

### Status Line Display

The custom status line shows real-time session information:

```
📂 project │ ✨ feature/xxx * │ 🤖 Opus 4 │ 📥 12.5K 📤 3.2K │ 💰 $0.45 │ ⏱️ 2m30s │ +42 -15 │ 🧠 ━━━━━━╌╌╌╌ 62%
```

| Icon | Description |
|------|-------------|
| 📂 | Current project directory |
| 🌿/✨/🐛/etc | Git branch with type-specific emoji (asterisk if uncommitted changes) |
| 🤖 | Current Claude model |
| 📥/📤 | Input/output token usage |
| 💰 | Session cost in USD |
| ⏱️ | Session duration |
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
- `feature-dev` - Feature development assistance
- `frontend-design` - Frontend design assistance
- `github` - GitHub integration
- `code-review` - Code review tools
- `linear` - Linear issue tracking integration
- `superpowers` - Advanced skills and workflows
- `typescript-lsp` - TypeScript language server

## Environment Variables

Create `~/.claude/.env.local` for local settings:

```bash
# Debug mode (1: enable, 0: disable)
# DEBUG=1

# Notification Settings (1: enable, 0: disable)
# Disabled by default to avoid interruptions - set to 1 to enable
NOTIFY_SYSTEM=0                          # macOS system notification
NOTIFY_SOUND=0                           # Sound alert (afplay)

# Push Notifications
NTFY_TOPIC=your-topic                    # ntfy.sh push notification
SLACK_WEBHOOK_URL=https://hooks.slack.com/...  # Slack webhook

# Vibe Monitor
VIBEMON_CACHE_PATH=~/.claude/statusline-cache.json  # Cache file path
VIBEMON_DESKTOP_URL=http://127.0.0.1:19280  # Desktop App URL
VIBEMON_SERIAL_PORT=/dev/cu.usbmodem1101   # USB Serial port
VIBEMON_ESP32_URL=http://192.168.1.100      # HTTP fallback (WiFi mode)
```

### Vibe Monitor CLI

The `vibe-monitor.py` script supports CLI commands for manual control:

```bash
# Lock monitor to a specific project
python3 ~/.claude/hooks/vibe-monitor.py --lock [project-name]

# Unlock monitor
python3 ~/.claude/hooks/vibe-monitor.py --unlock

# Get current status
python3 ~/.claude/hooks/vibe-monitor.py --status

# Get/set lock mode (first-project or on-thinking)
python3 ~/.claude/hooks/vibe-monitor.py --lock-mode
python3 ~/.claude/hooks/vibe-monitor.py --lock-mode first-project
```

## Related Projects

- [vibe-monitor](https://github.com/nalbam/vibe-monitor) - ESP32 status display for Claude Code
- [dotfiles](https://github.com/nalbam/dotfiles) - Development environment setup

## License

MIT
