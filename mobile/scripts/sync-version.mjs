#!/usr/bin/env node
/**
 * One version for both apps: mobile/package.json "version" (semver) becomes
 *   Android  versionName = version, versionCode = major*10000 + minor*100 + patch
 *   iOS      MARKETING_VERSION = version, CURRENT_PROJECT_VERSION = that same code
 * Runs before every `npm run sync` (presync) and can be run alone:
 *   node scripts/sync-version.mjs
 * Bump the version in package.json, never in the native projects by hand;
 * tests/unit/mobile-version.test.ts (website tests) fails when they drift.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));

export function versionCodeFor(version) {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
  if (!m) throw new Error(`mobile/package.json version must be major.minor.patch, got ${version}`);
  return Number(m[1]) * 10000 + Number(m[2]) * 100 + Number(m[3]);
}

const version = pkg.version;
const code = versionCodeFor(version);

const gradlePath = join(root, 'android', 'app', 'build.gradle');
let gradle = readFileSync(gradlePath, 'utf8');
gradle = gradle.replace(/versionCode \d+/, `versionCode ${code}`).replace(/versionName "[^"]*"/, `versionName "${version}"`);
writeFileSync(gradlePath, gradle);

const pbxPath = join(root, 'ios', 'App', 'App.xcodeproj', 'project.pbxproj');
let pbx = readFileSync(pbxPath, 'utf8');
pbx = pbx.replace(/MARKETING_VERSION = [^;]+;/g, `MARKETING_VERSION = ${version};`).replace(/CURRENT_PROJECT_VERSION = \d+;/g, `CURRENT_PROJECT_VERSION = ${code};`);
writeFileSync(pbxPath, pbx);

console.log(`mobile ${version}: Android versionCode ${code}, iOS CURRENT_PROJECT_VERSION ${code}`);
