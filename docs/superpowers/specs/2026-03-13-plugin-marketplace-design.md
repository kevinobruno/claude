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
- All skills under `skills/` (currently: `new-app-version`)

## Files Unchanged

- `settings.json` — personal Claude Code settings, not distributed via plugin
- `statusline-command.sh` — personal statusline script, not distributed via plugin
- `CLAUDE.md` — project instructions

## Trade-offs

- Self-referencing marketplace is slightly unusual but supported by the plugin system
- Single repo = single maintenance burden
- Version in `marketplace.json` must be kept in sync with `plugin.json` on new releases
