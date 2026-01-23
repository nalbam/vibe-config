# claude-config

Claude Code settings, agents, hooks, rules, and skills for consistent AI-assisted development environments.

## Quick Start

```bash
# Run sync script (clones repo if needed, then syncs to ~/.claude/)
bash -c "$(curl -fsSL nalbam.github.io/claude-config/sync.sh)"

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
claude-config/
├── sync.sh                   # Sync script (clone/pull + sync to ~/.claude/)
├── CLAUDE.md                 # Global Claude Code instructions
├── settings.json             # Permissions, hooks, status line config
│
├── agents/                   # Custom agent definitions
│   ├── architect.md          # System design and architecture
│   ├── builder.md            # Build error resolution
│   ├── code-reviewer.md      # Code review specialist
│   ├── debugger.md           # Debugging and error resolution
│   ├── doc-writer.md         # Documentation specialist
│   ├── planner.md            # Implementation planning (Opus)
│   ├── refactorer.md         # Code refactoring
│   └── test-writer.md        # Test generation
│
├── hooks/                    # Automated workflow hooks
│   ├── claude-monitor.sh     # Send status to Desktop app / ESP32
│   └── notify.sh             # Multi-platform notifications
│
├── rules/                    # Always-follow guidelines
│   ├── coding-style.md       # Immutability, file organization
│   ├── git-workflow.md       # Commit format, PR process
│   ├── language.md           # Response language (Korean)
│   ├── patterns.md           # API formats, common patterns
│   ├── performance.md        # Model selection strategy
│   ├── security.md           # Security best practices
│   └── testing.md            # TDD workflow, 80% coverage
│
├── skills/                   # User-invokable skills (/skill-name)
│   ├── docs-sync/            # Documentation sync and gap analysis
│   ├── pr-create/            # Create PR with proper format
│   └── validate/             # Run lint, typecheck, tests
│
└── sounds/                   # Audio notifications
    ├── ding1.mp3
    ├── ding2.mp3
    └── ding3.mp3
```

## Features

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
- `claude-monitor.sh` - Initialize monitor status

**PreToolUse:**
- `claude-monitor.sh` - Update monitor (working state)

**PostToolUse:**
- `claude-monitor.sh` - Update monitor (done state)

**Stop:**
- `notify.sh` - Send completion notifications
- `claude-monitor.sh` - Update monitor (idle state)

**Notification:**
- `notify.sh` - Send completion notifications
- `claude-monitor.sh` - Update monitor (notification state)

### Skills

User-invokable via `/skill-name`:

```bash
/validate      # Run lint, typecheck, tests with auto-fix
/docs-sync     # Analyze and update documentation
/pr-create     # Create pull request with proper format
```

### Notification System

The `notify.sh` hook supports multiple platforms:
- **macOS**: Native notifications + audio alerts
- **WSL**: PowerShell beep notifications
- **ntfy.sh**: Push notifications (set `NTFY_TOPIC`)
- **Slack**: Webhook notifications (set `SLACK_WEBHOOK_URL`)

### Claude Monitor

Display Claude Code status in real-time:

| Target | Description |
|--------|-------------|
| **Desktop App** | Frameless Electron app (macOS) on `localhost:19280` |
| **ESP32 Device** | ESP32-C6-LCD-1.47 via USB Serial or HTTP |

See [claude-monitor](https://github.com/nalbam/claude-monitor) for Desktop app and ESP32 firmware.

## Configuration

The `settings.json` file includes:

| Setting | Value | Description |
|---------|-------|-------------|
| `model` | `opus` | Default Claude model |
| `cleanupPeriodDays` | `30` | Conversation cleanup period |
| `MAX_THINKING_TOKENS` | `31999` | Extended thinking token limit |
| `statusLine` | `ccusage` | Show API usage in status line |

### Enabled Plugins

- `context7` - Up-to-date library documentation
- `frontend-design` - Frontend design assistance
- `code-review` - Code review tools
- `linear` - Linear issue tracking integration
- `superpowers` - Advanced skills and workflows

## Environment Variables

Create `~/.claude/.env.local` for local settings:

```bash
# Debug mode (1: enable, 0: disable)
# DEBUG=1

# Notification Settings (1: enable, 0: disable, default: 1)
NOTIFY_SYSTEM=1                          # macOS system notification
NOTIFY_SOUND=1                           # Sound alert (afplay)

# Push Notifications
NTFY_TOPIC=your-topic                    # ntfy.sh push notification
SLACK_WEBHOOK_URL=https://hooks.slack.com/...  # Slack webhook

# Claude Monitor
# CLAUDE_MONITOR_DESKTOP=$HOME/path/to/claude-monitor/desktop
ESP32_SERIAL_PORT=/dev/cu.usbmodem1101   # USB Serial port
ESP32_HTTP_URL=http://192.168.1.100      # HTTP fallback (WiFi mode)
```

## Related Projects

- [claude-monitor](https://github.com/nalbam/claude-monitor) - ESP32 status display for Claude Code
- [dotfiles](https://github.com/nalbam/dotfiles) - Development environment setup

## License

MIT
