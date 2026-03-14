# Plugin Marketplace Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json` to make this repo installable as a Claude Code plugin via `plugin marketplace add kevinobruno/claude` + `plugin install kolabs@kevinobruno/claude`.

**Architecture:** Two JSON files under `.claude-plugin/` — one declares this repo as a marketplace listing the `kolabs` plugin, the other declares this repo as the `kolabs` plugin itself. No code changes needed; the plugin system distributes `skills/` subdirectories automatically.

**Tech Stack:** JSON config files only; Claude Code plugin system.

---

## Chunk 1: Add plugin config files

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `.claude-plugin/plugin.json`

### Task 1: Create `.claude-plugin/marketplace.json`

**Files:**
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create `.claude-plugin/` directory and write `marketplace.json`**

```bash
mkdir -p .claude-plugin
```

Then create `.claude-plugin/marketplace.json` with this exact content:

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

- [ ] **Step 2: Verify the file exists and is valid JSON**

Run: `cat .claude-plugin/marketplace.json | jq .`
Expected: JSON prints without error, showing the `plugins` array with one entry named `kolabs`.

---

### Task 2: Create `.claude-plugin/plugin.json`

**Files:**
- Create: `.claude-plugin/plugin.json`

- [ ] **Step 1: Write `plugin.json`**

Create `.claude-plugin/plugin.json` with this exact content:

```json
{
  "name": "kolabs",
  "description": "kevinobruno's personal Claude Code skills collection",
  "version": "1.0.0"
}
```

- [ ] **Step 2: Verify the file exists and is valid JSON**

Run: `cat .claude-plugin/plugin.json | jq .`
Expected: JSON prints without error, showing `name` as `"kolabs"` and `version` as `"1.0.0"`.

- [ ] **Step 3: Verify versions match between the two files**

Run: `jq -r '.version' .claude-plugin/plugin.json && jq -r '.plugins[0].version' .claude-plugin/marketplace.json`
Expected: Both lines output `1.0.0`.

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json .claude-plugin/plugin.json
git commit -m "feat: add plugin marketplace config for kolabs"
```

Expected: commit succeeds with 2 files changed, 2 insertions.
