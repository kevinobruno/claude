# Plugin Marketplace Design

**Date:** 2026-03-13
**Topic:** Make `kevinobruno/claude` installable as a Claude Code plugin

## Goal

Allow other Claude Code users to install skills from this repo via:

```
/plugin marketplace add kevinobruno/claude
/plugin install kolabs@kevinobruno/claude
```

## Approach

Monorepo: this repo acts as both the **marketplace** (listing available plugins) and the **plugin itself** (`kolabs`).

## Files to Add

### `.claude-plugin/marketplace.json`

Makes this repo a marketplace. Lists `kolabs` as a plugin sourced from this same GitHub repo.

```json
{
  "name": "kevinobruno/claude",
  "plugins": [
    {
      "name": "kolabs",
      "source": { "source": "url", "url": "https://github.com/kevinobruno/claude.git" },
      "description": "kevinobruno's personal Claude Code skills collection",
      "version": "1.0.0",
      "strict": true
    }
  ]
}
```

### `.claude-plugin/plugin.json`

Makes this repo itself the `kolabs` plugin.

```json
{
  "name": "kolabs",
  "description": "kevinobruno's personal Claude Code skills collection",
  "version": "1.0.0"
}
```

## What Gets Installed

When a user installs `kolabs`, they get:
- All skills under `skills/` — including sibling files alongside each `SKILL.md` (e.g., `scripts/bump-version.js` in `new-app-version`). The plugin system distributes entire skill subdirectories, not just `SKILL.md` files (confirmed by inspecting the superpowers plugin install structure).

## Files Unchanged / Not Distributed

- `settings.json` — personal Claude Code settings, not distributed via plugin
- `statusline-command.sh` — personal statusline script, not distributed via plugin
- `CLAUDE.md` — project instructions

## Version Sync Strategy

Both `marketplace.json` and `plugin.json` carry a `version` field that must match on every release. To prevent silent drift, update both files together as part of any release commit. There is no automated enforcement — the release process (e.g., via the `new-app-version` skill's bump step) should be extended to update both files simultaneously.

## Trade-offs

- Self-referencing marketplace is slightly unusual but supported by the plugin system
- `strict: true` in `marketplace.json` tells the plugin system to enforce strict version matching during install, preventing partial or mismatched installs
- Single repo = single maintenance burden
