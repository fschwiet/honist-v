# Release Script Implementation Plan

**Goal:** Add a `pnpm release` Node script that performs the `publish-branch`
skill's steps (verify build, confirm `main` is synced with `origin/main`,
bump the patch version in both `plugin.json` files, commit, push) without
needing an LLM agent to run them.

**Architecture:** A pure version-computation module
(`scripts/release-version.mjs`) with unit tests, plus a thin orchestrating
CLI (`scripts/release.mjs`) that shells out to `pnpm` and `git` via
`spawnSync`, following the existing `verify-manifest-references.mjs` /
`manifest-references.mjs` split already used in this repo.

**Tech Stack:** Plain Node.js (`node:child_process`, `node:fs`), Node's
built-in test runner (`node --test`), no new dependencies.

## Global Constraints

- The package script is named `release`, invoked as `pnpm release` — not
  `publish`, because `pnpm publish` collides with pnpm's own built-in
  registry-publish command and would never reach a same-named package
  script.
- No flags (no `--dry-run` or similar) and no interactive prompts of any
  kind.
- Only plain `x.y.z` versions are supported — `version` fields with
  pre-release or build-metadata suffixes (`-beta`, `+build`) are rejected.
- The script aborts if the git worktree has any staged or unstaged changes
  before it runs.
- If `git push` fails after the version-bump commit has already been made
  locally, the script prints an explicit warning and exits non-zero — it
  does not retry, roll back, or detect/reuse the existing commit on a
  future run.
- Source spec: `docs/honist-v/specs/2026-07-30-publish-script-design.md`.

---

## File Structure

- Create: `scripts/release-version.mjs` — pure version-bump logic (no
  subprocess or filesystem access). Exports `computeVersionBump(entries)`.
- Create: `tests/release-version.test.mjs` — `node --test` unit tests for
  `computeVersionBump`.
- Create: `scripts/release.mjs` — the CLI entry point. Shells out to `pnpm`
  and `git`, imports `computeVersionBump` from `release-version.mjs`, runs
  `main()` unconditionally on load (this file is never imported by a test).
- Modify: `package.json` — add a `"release"` script entry.
- Modify: `README.md` — document `pnpm release` in the scripts table.

---

## Task 1: Pure version-bump logic (`release-version.mjs`)

**Files:**

- Create: `scripts/release-version.mjs`
- Test: `tests/release-version.test.mjs`

**Interfaces:**

- Produces: `computeVersionBump(entries)`, where `entries` is a two-element
  array of `{ label: string, value: unknown }`. Returns
  `{ ok: true, version: string }` on success, or
  `{ ok: false, message: string }` on failure. `label` identifies the
  source (e.g. a file path) for use in the failure message; `value` is
  whatever was read from that source's `version` field (expected to be a
  string, but not assumed to be).

- [ ] **Step 1: Write the failing tests**

Create `tests/release-version.test.mjs`:

```js
import assert from 'node:assert/strict';
import test from 'node:test';

import { computeVersionBump } from '../scripts/release-version.mjs';

test('bumps the patch version when both entries match', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.0.3' },
    { label: 'b.json', value: '0.0.3' },
  ]);

  assert.deepEqual(result, { ok: true, version: '0.0.4' });
});

test('bumps a double-digit patch version', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '1.2.9' },
    { label: 'b.json', value: '1.2.9' },
  ]);

  assert.deepEqual(result, { ok: true, version: '1.2.10' });
});

test('reports a mismatch between the two versions', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.0.3' },
    { label: 'b.json', value: '0.0.4' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json has 0\.0\.3/);
  assert.match(result.message, /b\.json has 0\.0\.4/);
});

test('rejects a version missing from a manifest', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: undefined },
    { label: 'b.json', value: '0.0.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a non-string version value', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: null },
    { label: 'b.json', value: '0.0.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a version with a pre-release suffix', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.0.3-beta' },
    { label: 'b.json', value: '0.0.3-beta' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a version with the wrong number of components', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.3' },
    { label: 'b.json', value: '0.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/release-version.test.mjs`

Expected: FAIL — `Cannot find module '../scripts/release-version.mjs'` (the
module doesn't exist yet).

- [ ] **Step 3: Implement `release-version.mjs`**

Create `scripts/release-version.mjs`:

```js
const VERSION_PATTERN = /^\d+\.\d+\.\d+$/;

function incrementPatch(version) {
  const [major, minor, patch] = version.split('.').map(Number);
  return `${major}.${minor}.${patch + 1}`;
}

export function computeVersionBump(entries) {
  for (const { label, value } of entries) {
    if (typeof value !== 'string' || !VERSION_PATTERN.test(value)) {
      return {
        ok: false,
        message: `${label} has an invalid version: ${JSON.stringify(value)} (expected "x.y.z")`,
      };
    }
  }

  const [first, second] = entries;
  if (first.value !== second.value) {
    return {
      ok: false,
      message: `plugin.json versions disagree: ${first.label} has ${first.value}, ${second.label} has ${second.value}`,
    };
  }

  return { ok: true, version: incrementPatch(first.value) };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test tests/release-version.test.mjs`

Expected: PASS — 7 tests, 0 failures.

- [ ] **Step 5: Lint**

Run: `pnpm lint`

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/release-version.mjs tests/release-version.test.mjs
git commit -m "Add pure version-bump logic for the release script"
```

---

## Task 2: Release CLI (`release.mjs`) and `pnpm release` wiring

**Files:**

- Create: `scripts/release.mjs`
- Modify: `package.json:11-19` (the `"scripts"` block)

**Interfaces:**

- Consumes: `computeVersionBump(entries)` from Task 1 —
  `{ ok: true, version: string } | { ok: false, message: string }`.
- Produces: the `scripts/release.mjs` CLI itself; nothing else depends on
  it.

- [ ] **Step 1: Implement `scripts/release.mjs`**

Create `scripts/release.mjs`:

```js
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

import { computeVersionBump } from './release-version.mjs';

const PLUGIN_MANIFESTS = ['plugin/.claude-plugin/plugin.json', 'plugin/.codex-plugin/plugin.json'];

function runCommand(cmd, args) {
  const result = spawnSync(cmd, args, { stdio: 'inherit', shell: true });
  return result.error === undefined && result.signal === null && result.status === 0;
}

function captureCommand(cmd, args) {
  const result = spawnSync(cmd, args, { encoding: 'utf8', shell: true });
  if (result.error !== undefined || result.signal !== null || result.status !== 0) {
    if (result.stderr) process.stderr.write(result.stderr);
    return { ok: false };
  }
  return { ok: true, stdout: result.stdout.trim() };
}

function verifyBuild() {
  return runCommand('pnpm', ['verify']);
}

function checkMainSynced() {
  const status = captureCommand('git', ['status', '--porcelain']);
  if (!status.ok) return false;
  if (status.stdout !== '') {
    console.error('worktree has uncommitted changes — commit or stash first.');
    return false;
  }

  const branch = captureCommand('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (!branch.ok) return false;
  if (branch.stdout !== 'main') {
    console.error(`current branch is "${branch.stdout}", not "main" — switch to main first.`);
    return false;
  }

  if (!runCommand('git', ['fetch', 'origin', 'main'])) return false;

  const counts = captureCommand('git', [
    'rev-list',
    '--left-right',
    '--count',
    'origin/main...HEAD',
  ]);
  if (!counts.ok) return false;
  const [left, right] = counts.stdout.split(/\s+/).map(Number);
  if (left > 0 && right > 0) {
    console.error('main has diverged from origin/main — reconcile first.');
    return false;
  }
  if (left > 0) {
    console.error('main is behind origin/main — pull/rebase first.');
    return false;
  }

  return true;
}

function bumpPatchVersion() {
  const entries = PLUGIN_MANIFESTS.map((filePath) => {
    const document = JSON.parse(readFileSync(filePath, 'utf8'));
    return { label: filePath, value: document.version, filePath, document };
  });

  const result = computeVersionBump(entries);
  if (!result.ok) {
    console.error(result.message);
    return undefined;
  }

  for (const entry of entries) {
    entry.document.version = result.version;
    writeFileSync(entry.filePath, `${JSON.stringify(entry.document, null, 2)}\n`);
  }

  if (!runCommand('git', ['add', ...PLUGIN_MANIFESTS])) return undefined;
  if (!runCommand('git', ['commit', '-m', `Bump version to ${result.version}`])) return undefined;

  return result.version;
}

function pushToOrigin() {
  return runCommand('git', ['push', 'origin', 'main']);
}

function main() {
  if (!verifyBuild()) {
    process.exitCode = 1;
    return;
  }

  if (!checkMainSynced()) {
    process.exitCode = 1;
    return;
  }

  const version = bumpPatchVersion();
  if (version === undefined) {
    process.exitCode = 1;
    return;
  }

  if (!pushToOrigin()) {
    console.error(
      `Version bumped to ${version} and committed locally, but the push failed. ` +
        'Push it manually once the problem is resolved: git push origin main',
    );
    process.exitCode = 1;
    return;
  }

  console.log(`Released ${version} and pushed to origin/main.`);
}

main();
```

Note: `bumpPatchVersion()` assumes both manifest files parse as valid JSON.
This is safe because `verifyBuild()` runs `pnpm verify` first, which
includes `verify:manifest-references` — that check already fails the whole
script (via `verifyBuild()`'s early return) if either manifest has invalid
JSON, before `bumpPatchVersion()` ever runs.

- [ ] **Step 2: Add the `release` script to `package.json`**

Modify `package.json`, inside the `"scripts"` block (currently
`package.json:11-19`), adding one entry:

```json
  "scripts": {
    "release": "node scripts/release.mjs",
    "verify": "pnpm format:check && pnpm lint && pnpm lint:md && pnpm test:manifest-references && pnpm verify:manifest-references",
    "verify:manifest-references": "node scripts/verify-manifest-references.mjs",
    "test:manifest-references": "node --test tests/manifest-references.test.mjs",
    "lint": "eslint .",
    "lint:md": "markdownlint-cli2",
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  },
```

- [ ] **Step 3: Lint and format-check**

Run: `pnpm lint && pnpm format:check`

Expected: no errors. If `format:check` fails on the new file, run
`pnpm format` and re-check.

- [ ] **Step 4: Manually verify the success path in a scratch repo**

This script's job is to shell out to real `git`/`pnpm` commands, which
isn't safely unit-testable (running it for real would commit and push in
whatever repo it's pointed at) — this matches the spec's decision not to
add a broader integration test. Instead, verify it by hand against a
disposable scratch repo, never against this repository itself.

Run (from the honist-v repo root, using the Bash tool):

```bash
set -e
SCRATCH=$(mktemp -d)
ORIGIN="$SCRATCH/origin.git"
WORK="$SCRATCH/work"

git init --bare "$ORIGIN"
git init "$WORK"
cd "$WORK"
git remote add origin "$ORIGIN"
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p plugin/.claude-plugin plugin/.codex-plugin scripts
printf '{"name":"scratch","version":"0.0.3"}\n' > plugin/.claude-plugin/plugin.json
printf '{"name":"scratch","version":"0.0.3"}\n' > plugin/.codex-plugin/plugin.json
cp "$OLDPWD/scripts/release.mjs" scripts/release.mjs
cp "$OLDPWD/scripts/release-version.mjs" scripts/release-version.mjs
printf '{"name":"scratch","private":true,"type":"module","scripts":{"verify":"node -e \\"process.exit(0)\\""}}\n' > package.json

git add -A
git commit -m "initial"
git branch -M main
git push -u origin main

node scripts/release.mjs
echo "exit code: $?"
cat plugin/.claude-plugin/plugin.json
git log --oneline -3
git log origin/main --oneline -1
```

Expected:

- Exit code `0`.
- Both `plugin.json` files now show `"version": "0.0.4"`.
- The local `main` and `origin/main` both point at the new "Bump version to
  0.0.4" commit (the last two `git log` lines show the same commit).
- Final stdout line: `Released 0.0.4 and pushed to origin/main.`

- [ ] **Step 5: Manually verify the failure paths in the same scratch repo**

Continue in the same `$WORK` directory (Bash tool, same session so `$WORK`
and `$SCRATCH` are still set):

```bash
cd "$WORK"

# Dirty worktree
echo dirty >> README-scratch.md
node scripts/release.mjs; echo "exit code: $?"
# Expected: exit code 1, stderr "worktree has uncommitted changes — commit or stash first."
rm README-scratch.md

# Wrong branch
git checkout -b other
node scripts/release.mjs; echo "exit code: $?"
# Expected: exit code 1, stderr mentions branch "other", not "main"
git checkout main

# Version mismatch
sed -i 's/0.0.4/0.0.5/' plugin/.claude-plugin/plugin.json
git add -A && git commit -m "mismatch"
node scripts/release.mjs; echo "exit code: $?"
# Expected: exit code 1, stderr shows both versions disagreeing (0.0.5 vs 0.0.4)
git reset --hard HEAD~1

# Behind origin
git commit --allow-empty -m "diverging local commit"
CLONE="$SCRATCH/other-clone"
git clone "$ORIGIN" "$CLONE"
(cd "$CLONE" && git commit --allow-empty -m "someone else's push" && git push)
node scripts/release.mjs; echo "exit code: $?"
# Expected: exit code 1, stderr "main has diverged from origin/main — reconcile first."
# (both sides have a commit the other lacks, since the local empty commit
# and the "someone else's push" commit diverged from the same point)

cd /
rm -rf "$SCRATCH"
```

Confirm each expected message and exit code matches before proceeding —
if any diverge, fix `scripts/release.mjs` and re-run Step 4 and Step 5
from the top with a fresh scratch repo.

- [ ] **Step 6: Commit**

```bash
git add scripts/release.mjs package.json
git commit -m "Add pnpm release script"
```

---

## Task 3: Document the script and run full verification

**Files:**

- Modify: `README.md` (the scripts table, currently `README.md:57-67`)

- [ ] **Step 1: Add `pnpm release` to the README scripts table**

Modify `README.md`, changing:

```markdown
Other useful scripts:

| Script                            | Description                             |
| --------------------------------- | --------------------------------------- |
| `pnpm verify:manifest-references` | Check references in committed manifests |
| `pnpm test:manifest-references`   | Test manifest-reference verification    |
| `pnpm lint`                       | Run ESLint                              |
| `pnpm lint:md`                    | Lint Markdown with markdownlint         |
| `pnpm format`                     | Format all files with Prettier          |
| `pnpm format:check`               | Check formatting without writing        |
```

to:

```markdown
Other useful scripts:

| Script                            | Description                             |
| --------------------------------- | --------------------------------------- |
| `pnpm release`                    | Verify, bump the patch version, and push main |
| `pnpm verify:manifest-references` | Check references in committed manifests |
| `pnpm test:manifest-references`   | Test manifest-reference verification    |
| `pnpm lint`                       | Run ESLint                              |
| `pnpm lint:md`                    | Lint Markdown with markdownlint         |
| `pnpm format`                     | Format all files with Prettier          |
| `pnpm format:check`               | Check formatting without writing        |
```

- [ ] **Step 2: Lint markdown**

Run: `pnpm lint:md`

Expected: no errors. If the table columns report misaligned formatting,
run `pnpm format` and re-check.

- [ ] **Step 3: Run full verification**

Run: `pnpm verify`

Expected: all stages pass (format check, lint, markdown lint, manifest
reference test, manifest reference verify).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Document the pnpm release script"
```
