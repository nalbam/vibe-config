# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-assisted development environment settings for Claude Code and Kiro. This repository manages configuration files that are synced to `~/.claude/` and `~/.kiro/`.

## Commands

```bash
# Sync settings to user directories
./sync.sh          # Auto-yes mode (sync all without prompts, default)
./sync.sh -n       # Dry-run mode (show changes only)
./sync.sh -h       # Show help
```

## Architecture

### Sync Flow

```
vibe-config/
├── claude/  ──sync──>  ~/.claude/
└── kiro/    ──sync──>  ~/.kiro/
```

The `sync.sh` script:
1. Clones/pulls from `https://github.com/nalbam/vibe-config.git` to `~/.vibe-config`
2. Compares files using MD5 hashes
3. Shows diffs for changed files
4. Syncs all changes automatically (default auto-yes mode)

### Claude Code Settings (`claude/`)

| Component | Purpose |
|-----------|---------|
| `CLAUDE.md` | Global instructions loaded for all projects |
| `settings.json` | Permissions, hooks, model (opus), plugins |
| `agents/*.md` | Specialized sub-agents (planner, builder, debugger, etc.) |
| `hooks/` | Event-driven scripts (vibe-monitor.py, notify.sh) |
| `rules/*.md` | Always-loaded guidelines (language, security, testing) |
| `skills/*/SKILL.md` | User-invokable skills via `/skill-name` |
| `sounds/*.mp3` | Audio notifications |

### Hook Events

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | vibe-monitor.py | Initialize status |
| UserPromptSubmit | vibe-monitor.py | Update to thinking state |
| PreToolUse | vibe-monitor.py | Update to working state |
| Stop | notify.sh, vibe-monitor.py | Send notifications, done state |
| Notification | notify.sh, vibe-monitor.py | Alert user for input |

### Kiro Settings (`kiro/`)

Contains hook files for Kiro IDE/CLI vibe-monitor integration.

## Key Files

- `claude/.env.example` - Template for environment variables (`~/.claude/.env.local`)
- `claude/settings.json` - Defines permissions, hooks, enabled plugins
- `claude/statusline.py` - Custom status line showing usage, cost, context

## Testing Changes

1. Make edits in this repository
2. Run `./sync.sh -n` to preview changes
3. Run `./sync.sh` to interactively apply changes
4. Test in a new Claude Code session
