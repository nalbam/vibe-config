# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-assisted development environment settings for Claude Code and Kiro. This repository manages configuration files that are synced to `~/.claude/` and `~/.kiro/`.

## Commands

```bash
./sync.sh          # Sync all changes (default)
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
4. Syncs all changes automatically

### Claude Code Settings (`claude/`)

| Component | Purpose |
|-----------|---------|
| `CLAUDE.md` | Global instructions loaded for all projects |
| `settings.json` | Permissions, hooks, model (opus), plugins |
| `agents/*.md` | Specialized sub-agents (planner, builder, debugger, etc.) |
| `hooks/vibemon.py` | VibeMon status updates |
| `rules/*.md` | Always-loaded guidelines (language, security, testing) |
| `skills/*/SKILL.md` | User-invokable skills via `/skill-name` |
| `statusline.py` | Custom status line showing usage, cost, context, token reset timer |

### Hook Events

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | vibemon.py | Initialize status |
| UserPromptSubmit | vibemon.py | Update to thinking state |
| PreToolUse | vibemon.py | Update to working state |
| Stop | vibemon.py | Done state |
| Notification | vibemon.py | Alert user for input |

### Kiro Settings (`kiro/`)

| Component | Purpose |
|-----------|---------|
| `agents/default.json` | Default agent configuration |
| `hooks/vibemon.py` | VibeMon status updates |

## Testing Changes

1. Make edits in this repository
2. Run `./sync.sh -n` to preview changes
3. Run `./sync.sh` to apply changes
4. Test in a new Claude Code session
