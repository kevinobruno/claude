---
name: new-app-version
description: Use when releasing a new version of a React Native app - tagging, publishing to GitHub, and building Android and/or iOS bundles.
---

# New App Version
    
Full end-to-end release flow: version bump → tag + GitHub release → Android and/or iOS build.

## Steps

### 1. Gather inputs

Ask (if not already provided):
- **Bump type**: `major` | `minor` | `patch` | explicit version (e.g. `2.3.1`)

### 2. Bump version

Use the base directory shown in the skill header (e.g. `Base directory for this skill: /path/to/skill`) to locate the bundled script:

```bash
node <SKILL_BASE_DIR>/scripts/bump-version.js <type>
```

### 3. Commit version files

Find the iOS `.xcodeproj` path with:
```bash
find ios -name "project.pbxproj" | head -1
```

Then commit:
```bash
git add package.json android/app/build.gradle ios/<AppName>.xcodeproj/project.pbxproj
git commit -m "chore: bump version to <newVersion> (build <newBuildNumber>)"
```

### 4. Tag and push to GitHub

```bash
git tag v<newVersion>
git push && git push --tags
```

### 5. Create GitHub release

Get commits since the last tag (or all commits if no tags exist):
```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
if [ -z "$LAST_TAG" ]; then
  git log --oneline --no-decorate
else
  git log "${LAST_TAG}..HEAD" --oneline --no-decorate
fi
```

Read the commit list and write a concise, human-friendly release note in markdown. Group related changes under headings (e.g. `## Features`, `## Bug Fixes`, `## Improvements`). Omit chore/housekeeping commits unless they're significant.

Then create the release:
```bash
gh release create v<newVersion> --title "v<newVersion>" --notes "<generated notes>"
```

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
cd android && ./gradlew bundleRelease && cd ..
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
