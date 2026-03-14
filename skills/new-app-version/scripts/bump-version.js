#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const PACKAGE_JSON = path.join(ROOT, 'package.json');
const BUILD_GRADLE = path.join(ROOT, 'android', 'app', 'build.gradle');

function findPbxproj() {
  const iosDir = path.join(ROOT, 'ios');
  const entries = fs.readdirSync(iosDir);
  const xcodeproj = entries.find(e => e.endsWith('.xcodeproj'));
  if (!xcodeproj) throw new Error('No .xcodeproj found in ios/');
  return path.join(iosDir, xcodeproj, 'project.pbxproj');
}

/**
 * Bumps a MAJOR.MINOR version string.
 * @param {string} current  e.g. "1.2"
 * @param {string} type     "major" | "minor" | explicit "X.Y"
 * @returns {string} new version string
 */
function bumpVersion(current, type) {
  const match = current.match(/^(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid version string: ${current}`);
  }
  let [, major, minor] = match.map(Number);

  if (type === 'major') {
    return `${major + 1}.0`;
  }
  if (type === 'minor') {
    return `${major}.${minor + 1}`;
  }
  // Explicit version — validate it
  if (/^\d+\.\d+$/.test(type)) {
    return type;
  }
  throw new Error(`Unknown bump type: ${type}`);
}

/**
 * Increments a build number by 1.
 * @param {number|string} current
 * @returns {number}
 */
function nextBuildNumber(current) {
  return parseInt(String(current), 10) + 1;
}

function readPackageVersion() {
  const pkg = JSON.parse(fs.readFileSync(PACKAGE_JSON, 'utf8'));
  return pkg.version;
}

function readAndroidBuildNumber() {
  const content = fs.readFileSync(BUILD_GRADLE, 'utf8');
  const m = content.match(/versionCode\s+(\d+)/);
  if (!m) throw new Error('versionCode not found in build.gradle');
  return parseInt(m[1], 10);
}

function updatePackageJson(newVersion) {
  const raw = fs.readFileSync(PACKAGE_JSON, 'utf8');
  const updated = raw.replace(
    /"version":\s*"[^"]*"/,
    `"version": "${newVersion}"`,
  );
  fs.writeFileSync(PACKAGE_JSON, updated, 'utf8');
}

function updateAndroid(newVersion, newBuildNumber) {
  let content = fs.readFileSync(BUILD_GRADLE, 'utf8');
  content = content.replace(
    /versionCode\s+\d+/,
    `versionCode ${newBuildNumber}`,
  );
  content = content.replace(
    /versionName\s+"[^"]*"/,
    `versionName "${newVersion}"`,
  );
  fs.writeFileSync(BUILD_GRADLE, content, 'utf8');
}

function updateIos(newVersion, newBuildNumber) {
  const PBXPROJ = findPbxproj();
  let content = fs.readFileSync(PBXPROJ, 'utf8');
  // CURRENT_PROJECT_VERSION appears twice (Debug + Release config)
  content = content.replace(
    /CURRENT_PROJECT_VERSION = \d+;/g,
    `CURRENT_PROJECT_VERSION = ${newBuildNumber};`,
  );
  // MARKETING_VERSION appears twice (Debug + Release config)
  content = content.replace(
    /MARKETING_VERSION = [^;]+;/g,
    `MARKETING_VERSION = ${newVersion};`,
  );
  fs.writeFileSync(PBXPROJ, content, 'utf8');
}

function main() {
  const bumpType = process.argv[2];
  if (!bumpType) {
    console.error('Usage: node scripts/bump-version.js [major|minor|<version>]');
    process.exit(1);
  }

  const currentVersion = readPackageVersion();
  const currentBuildNumber = readAndroidBuildNumber();
  const newVersion = bumpVersion(currentVersion, bumpType);
  const newBuildNumber = nextBuildNumber(currentBuildNumber);

  updatePackageJson(newVersion);
  updateAndroid(newVersion, newBuildNumber);
  updateIos(newVersion, newBuildNumber);

  console.log(`\nVersion bumped:`);
  console.log(`  ${currentVersion} → ${newVersion}`);
  console.log(`  build: ${currentBuildNumber} → ${newBuildNumber}`);
  console.log(`\nFiles updated:`);
  console.log(`  package.json`);
  console.log(`  android/app/build.gradle`);
  console.log(`  ${path.relative(ROOT, findPbxproj())}`);
}

main();
