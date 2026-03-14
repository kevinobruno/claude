# new-app-version: Platform Build Prompt Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After creating the GitHub release, ask the user which platforms they want to build (Android, iOS, both, or neither) and execute only the selected builds.

**Architecture:** Modify `SKILL.md` to (a) update the frontmatter description and summary line to mention iOS, and (b) replace the unconditional Android build step with a user decision point followed by conditional Android and iOS build steps, each with explicit skip guards.

**Tech Stack:** Markdown (skill file), bash commands inline in skill steps.

---

## Chunk 1: Update SKILL.md

### Task 1: Rewrite the skill's build section

**Files:**
- Modify: `skills/new-app-version/SKILL.md` (lines 3, 8, and 64–end)

- [ ] **Step 1: Update the frontmatter description (line 3)**

Change:
```
description: Use when releasing a new version of a React Native app - tagging, publishing to GitHub, and building the Android bundle.
```
To:
```
description: Use when releasing a new version of a React Native app - tagging, publishing to GitHub, and building Android and/or iOS bundles.
```

- [ ] **Step 2: Update the summary line (line 8)**

Change:
```
Full end-to-end release flow: version bump → tag + GitHub release → Android build.
```
To:
```
Full end-to-end release flow: version bump → tag + GitHub release → Android and/or iOS build.
```

- [ ] **Step 3: Replace steps 6–7 with a platform prompt + conditional build steps**

Remove everything from `### 6. Build Android release bundle` to the end of the file and replace with:

```markdown
### 6. Ask which platforms to build

After the GitHub release is created, ask the user:

> "GitHub release created. Which platforms do you want to build?
> - **a** — Android only
> - **i** — iOS only
> - **b** — Both Android and iOS
> - **n** — Neither (skip builds)"

Wait for the user's response before continuing.

### 7. Build Android (if selected)

**Skip this step if the user chose `i` (iOS only) or `n` (neither).**

```bash
cd android && ./gradlew bundleRelease
```

On success, report the AAB path:

```
android/app/build/outputs/bundle/release/app-release.aab
```

### 8. Build iOS (if selected)

**Skip this step if the user chose `a` (Android only) or `n` (neither).**

First, find the Xcode workspace name:

```bash
ls ios/*.xcworkspace
```

Then archive:

```bash
xcodebuild -workspace ios/<AppName>.xcworkspace \
  -scheme <AppName> \
  -configuration Release \
  -archivePath ios/build/<AppName>.xcarchive \
  archive
```

Substitute `<AppName>` with the name found in the previous command (e.g. if `ls` returns `ios/MyApp.xcworkspace`, use `MyApp`).

On success, report the archive path:

```
ios/build/<AppName>.xcarchive
```
```

- [ ] **Step 4: Verify the full file**

Read the complete updated `SKILL.md` and confirm:
- Frontmatter `description` mentions both Android and iOS
- Summary line (line 8) mentions both platforms
- Steps are numbered 1–8 with no gaps
- Step 6 asks the user with exactly four options: `a`, `i`, `b`, `n`
- Step 7 has an explicit "Skip if `i` or `n`" guard
- Step 8 has an explicit "Skip if `a` or `n`" guard
- Step 8 includes the `ls ios/*.xcworkspace` discovery command before the build
- Both steps 7 and 8 report their output artifact paths
- No stale content from the old step 6 or 7 remains

- [ ] **Step 5: Commit**

```bash
git add skills/new-app-version/SKILL.md
git commit -m "feat: prompt user for platform selection after GitHub release"
```
