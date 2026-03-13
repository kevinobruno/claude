# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a Claude Code configuration repository containing:
- `settings.json` — Claude Code settings (plugins, statusline, permissions)
- `statusline-command.sh` — Bash script powering the Claude Code status line display

## Architecture

### settings.json
Configures Claude Code with:
- `superpowers@claude-plugins-official` plugin enabled
- Statusline sourced from `statusline-command.sh` via `bash ~/.claude/statusline-command.sh`
- Pre-approved permissions for common dev commands (`npm test`, `npm run lint`, `npx jest`, `npx tsc`, `git add`, `git commit`)

### statusline-command.sh
Reads a JSON blob from stdin (Claude Code's status context) and outputs a 3-line statusline:
- **Line 1**: Full-width context window usage bar showing model name, fill level, and token count
- **Line 2**: `[user][git info with branch/staged/unstaged][abbreviated cwd]`
- **Line 3**: `[SESSION id][msg count | tool count][duration][+lines/-lines]`

Key implementation details:
- Uses a single `jq` call to parse the input JSON into shell variables via TSV
- Git info is gathered with `git status --porcelain=v2 --branch` and parsed by `awk`
- Context bar distinguishes "initial" (system/cache baseline from first message) vs "ours" (growth above baseline) using different colors
- Token counts use shade blocks (`░▒▓█`) for sub-character granularity
- Color thresholds: green <50%, yellow ≥50%, orange ≥65%, red ≥75% context usage
- Targets <100ms execution; avoids subshells and multiple external process calls where possible
- Cross-platform: handles GNU/BSD `date` differences for macOS vs Linux
- Stats are read from `~/.claude/stats-cache.json` (maintained externally by Claude Code)
