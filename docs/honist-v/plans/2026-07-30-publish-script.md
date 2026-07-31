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
  pre-release or build-metadata suffixes (`-beta`, `+build`) or leading
  zeros are rejected.
- The script aborts if the git worktree has any staged or unstaged changes
  before it runs.
- If `git push` fails after the version-bump commit has already been made
  locally, the script prints an explicit warning and exits non-zero — it
  does not retry, roll back, or detect/reuse the existing commit on a
  future run.
- `spawnSync` must never be called with `shell: true` for a `git` command:
  on Windows, `shell: true` collapses array arguments into one string
  without safely re-quoting them, which breaks the `-m "<message>"` commit
  message into separate words (verified locally — see Task 2, Step 1's
  note). `shell: true` is only used for `pnpm`, whose arguments never
  contain spaces, and which — as a `.cmd` shim on Windows — cannot be
  spawned directly without a shell.
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
- Modify: `package.json` — add `"test:release-version"` and `"release"`
  script entries, and wire the former into `"verify"`.
- Modify: `README.md` — document the new scripts in the scripts table.

---

## Task 1: Pure version-bump logic (`release-version.mjs`)

**Files:**

- Create: `scripts/release-version.mjs`
- Test: `tests/release-version.test.mjs`
- Modify: `package.json:11-19` (the `"scripts"` block)

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

test('rejects a version component with a leading zero', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.01.3' },
    { label: 'b.json', value: '0.01.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a patch number outside the safe integer range', () => {
  const huge = String(Number.MAX_SAFE_INTEGER + 1);
  const result = computeVersionBump([
    { label: 'a.json', value: `0.0.${huge}` },
    { label: 'b.json', value: `0.0.${huge}` },
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
const VERSION_PATTERN = /^(\d+)\.(\d+)\.(\d+)$/;

function parseVersion(value) {
  if (typeof value !== 'string') return undefined;
  const match = VERSION_PATTERN.exec(value);
  if (!match) return undefined;

  const [major, minor, patch] = match.slice(1).map(Number);
  if (![major, minor, patch].every(Number.isSafeInteger)) return undefined;
  // Rejects leading zeros (e.g. "01") and any precision loss from Number(),
  // since a canonical value round-trips back to the original string.
  if (`${major}.${minor}.${patch}` !== value) return undefined;

  return { major, minor, patch };
}

export function computeVersionBump(entries) {
  const parsed = entries.map((entry) => ({ ...entry, parsed: parseVersion(entry.value) }));

  for (const entry of parsed) {
    if (!entry.parsed) {
      return {
        ok: false,
        message: `${entry.label} has an invalid version: ${JSON.stringify(entry.value)} (expected "x.y.z")`,
      };
    }
  }

  const [first, second] = parsed;
  if (first.value !== second.value) {
    return {
      ok: false,
      message: `plugin.json versions disagree: ${first.label} has ${first.value}, ${second.label} has ${second.value}`,
    };
  }

  const { major, minor, patch } = first.parsed;
  return { ok: true, version: `${major}.${minor}.${patch + 1}` };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test tests/release-version.test.mjs`

Expected: PASS — 9 tests, 0 failures.

- [ ] **Step 5: Lint**

Run: `pnpm lint`

Expected: no errors.

- [ ] **Step 6: Wire the test into `pnpm verify`**

Modify `package.json`, inside the `"scripts"` block (currently
`package.json:11-19`):

```json
  "scripts": {
    "verify": "pnpm format:check && pnpm lint && pnpm lint:md && pnpm test:manifest-references && pnpm test:release-version && pnpm verify:manifest-references",
    "verify:manifest-references": "node scripts/verify-manifest-references.mjs",
    "test:manifest-references": "node --test tests/manifest-references.test.mjs",
    "test:release-version": "node --test tests/release-version.test.mjs",
    "lint": "eslint .",
    "lint:md": "markdownlint-cli2",
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  },
```

- [ ] **Step 7: Confirm the new script entry works**

Run: `pnpm test:release-version`

Expected: PASS — same 9 tests as Step 4, run through the new package script.

- [ ] **Step 8: Commit**

```bash
git add scripts/release-version.mjs tests/release-version.test.mjs package.json
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

function runCommand(cmd, args, { shell = false } = {}) {
  const result = spawnSync(cmd, args, { stdio: 'inherit', shell });
  return result.error === undefined && result.signal === null && result.status === 0;
}

function captureCommand(cmd, args) {
  const result = spawnSync(cmd, args, { encoding: 'utf8' });
  if (result.error !== undefined || result.signal !== null || result.status !== 0) {
    if (result.stderr) process.stderr.write(result.stderr);
    return { ok: false };
  }
  return { ok: true, stdout: result.stdout.trim() };
}

function verifyBuild() {
  // pnpm resolves to a .cmd shim on Windows, which Node can only spawn via
  // a shell. Its arguments never contain spaces, so this is safe — unlike
  // git commands below, which must NOT use shell: true (see Global
  // Constraints: it breaks multi-word arguments like the commit message).
  return runCommand('pnpm', ['verify'], { shell: true });
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

**Why `runCommand`'s `git` calls never pass `shell: true`:** an earlier
draft of this script used `shell: true` for every subprocess call,
including `git commit -m "Bump version to 0.0.4"`. On Windows, `spawnSync`
with `shell: true` joins the array arguments into a single command string
without re-quoting entries that contain spaces, so the shell parsed that as
`git commit -m Bump version to 0.0.4` — four separate arguments, which
`git` rejected as unknown pathspecs (`version`, `to`, `0.0.4`) instead of
treating them as one commit message. This was reproduced directly:
`spawnSync('git', ['commit', '-m', 'Bump version to 0.0.4', ...], { shell:
true })` fails with `pathspec 'version' did not match any file(s)`. `git`
resolves as a real executable and works correctly with `shell: false`
(the default), so only `verifyBuild()`'s call to `pnpm` — which needs a
shell to run its Windows `.cmd` shim, and never has arguments containing
spaces — opts into `shell: true`.

- [ ] **Step 2: Add the `release` script to `package.json`**

Modify `package.json`, inside the `"scripts"` block (already updated by
Task 1, Step 6):

```json
  "scripts": {
    "release": "node scripts/release.mjs",
    "verify": "pnpm format:check && pnpm lint && pnpm lint:md && pnpm test:manifest-references && pnpm test:release-version && pnpm verify:manifest-references",
    "verify:manifest-references": "node scripts/verify-manifest-references.mjs",
    "test:manifest-references": "node --test tests/manifest-references.test.mjs",
    "test:release-version": "node --test tests/release-version.test.mjs",
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

- [ ] **Step 4: Manually verify every path in a scratch repo**

This script's job is to shell out to real `git`/`pnpm` commands, which
isn't safely unit-testable (running it for real would commit and push in
whatever repo it's pointed at) — this matches the spec's decision not to
add a broader integration test. Instead, verify it by hand against a
disposable scratch repo, never against this repository itself.

Run the entire block below as **one** Bash tool call — the Bash tool does
not preserve shell state (working directory aside) between separate calls,
so splitting this across multiple calls would lose the `$WORK`/`$SCRATCH`
variables set at the top. The script prints `PASS`/`FAIL` for each check
and a final summary instead of relying on `set -e` (which would abort the
whole walkthrough at the first *expected* failure, before its own
assertion ran).

```bash
SCRATCH=$(mktemp -d)
ORIGIN="$SCRATCH/origin.git"
WORK="$SCRATCH/work"
FAILURES=0

check_eq() {
  if [ "$1" = "$2" ]; then echo "PASS: $3"; else
    echo "FAIL: $3 (expected [$2], got [$1])"; FAILURES=$((FAILURES + 1))
  fi
}
check_ne() {
  if [ "$1" != "$2" ]; then echo "PASS: $3"; else
    echo "FAIL: $3 (expected different values, both [$1])"; FAILURES=$((FAILURES + 1))
  fi
}
check_contains() {
  if grep -q "$1" "$2"; then echo "PASS: $3"; else
    echo "FAIL: $3 (pattern [$1] not found in $2)"; FAILURES=$((FAILURES + 1))
  fi
}

git init --bare "$ORIGIN"
git -C "$ORIGIN" symbolic-ref HEAD refs/heads/main
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
git commit -q -m "initial"
git branch -M main
git push -qu origin main

# --- Success path ---
node scripts/release.mjs
check_eq "$?" "0" "success path exits 0"
check_contains '"version": "0.0.4"' plugin/.claude-plugin/plugin.json "claude plugin.json bumped to 0.0.4"
check_contains '"version": "0.0.4"' plugin/.codex-plugin/plugin.json "codex plugin.json bumped to 0.0.4"
check_eq "$(git rev-parse HEAD)" "$(git rev-parse origin/main)" "local main matches origin/main after push"

# --- Dirty worktree ---
echo dirty >> untracked-scratch.txt
node scripts/release.mjs 2> /tmp/release-stderr.txt
check_eq "$?" "1" "dirty worktree exits 1"
check_contains "uncommitted changes" /tmp/release-stderr.txt "dirty worktree message printed"
rm untracked-scratch.txt

# --- Wrong branch ---
git checkout -q -b other
node scripts/release.mjs 2> /tmp/release-stderr.txt
check_eq "$?" "1" "wrong branch exits 1"
check_contains 'not "main"' /tmp/release-stderr.txt "wrong branch message printed"
git checkout -q main

# --- Version mismatch ---
sed -i 's/0.0.4/0.0.5/' plugin/.claude-plugin/plugin.json
git commit -aqm "mismatch"
node scripts/release.mjs 2> /tmp/release-stderr.txt
check_eq "$?" "1" "version mismatch exits 1"
check_contains "0.0.5" /tmp/release-stderr.txt "mismatch message shows the offending version"
git reset -q --hard HEAD~1

# --- Behind origin (origin has a commit local hasn't fetched) ---
CLONE="$SCRATCH/other-clone"
git clone -q "$ORIGIN" "$CLONE"
(cd "$CLONE" && git config user.email t@e.com && git config user.name T \
  && git commit -q --allow-empty -m "someone else's push" && git push -q)
node scripts/release.mjs 2> /tmp/release-stderr.txt
check_eq "$?" "1" "behind origin exits 1"
check_contains "behind origin/main" /tmp/release-stderr.txt "behind message printed"

# --- Diverged (both sides have a commit the other lacks) ---
git commit -q --allow-empty -m "local-only commit"
node scripts/release.mjs 2> /tmp/release-stderr.txt
check_eq "$?" "1" "diverged exits 1"
check_contains "diverged from origin/main" /tmp/release-stderr.txt "diverged message printed"
git reset -q --hard origin/main

# --- Push failure (everything else checks out, but the remote rejects) ---
mkdir -p "$ORIGIN/hooks"
printf '#!/bin/sh\nexit 1\n' > "$ORIGIN/hooks/pre-receive"
chmod +x "$ORIGIN/hooks/pre-receive"
node scripts/release.mjs 2> /tmp/release-stderr.txt
check_eq "$?" "1" "push failure exits 1"
check_contains "push failed" /tmp/release-stderr.txt "push-failure warning printed"
check_contains '"version": "0.0.5"' plugin/.claude-plugin/plugin.json "version bumped locally despite push failure"
check_ne "$(git rev-parse HEAD)" "$(git rev-parse origin/main)" "local commit was not pushed"
rm "$ORIGIN/hooks/pre-receive"

echo "----"
if [ "$FAILURES" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "$FAILURES CHECK(S) FAILED"; fi

cd /
rm -rf "$SCRATCH"
```

Expected: every line reads `PASS: ...`, and the summary reads
`ALL CHECKS PASSED`. If any line reads `FAIL: ...`, fix `scripts/release.mjs`
and re-run this entire step from the top with a fresh scratch repo (state
from a failed run should not be reused).

- [ ] **Step 5: Commit**

```bash
git add scripts/release.mjs package.json
git commit -m "Add pnpm release script"
```

---

## Task 3: Document the script and run full verification

**Files:**

- Modify: `README.md` (the scripts table, currently `README.md:57-67`)

- [ ] **Step 1: Add the new scripts to the README scripts table**

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

| Script                            | Description                                   |
| --------------------------------- | ---------------------------------------------- |
| `pnpm release`                    | Verify, bump the patch version, and push main |
| `pnpm verify:manifest-references` | Check references in committed manifests |
| `pnpm test:manifest-references`   | Test manifest-reference verification    |
| `pnpm test:release-version`       | Test the release script's version-bump logic |
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
reference test, release-version test, manifest reference verify).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Document the pnpm release script"
```
