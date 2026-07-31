# Publish Script Design

## Goal

Add a `pnpm release` script that performs the release steps currently
described by the `publish-branch` skill, without requiring an LLM agent to
interpret and execute those steps by hand. The script codifies the skill's
behavior as plain Node code: verify the build, confirm `main` is synced with
`origin/main`, bump the patch version in both `plugin.json` files, commit,
and push.

The script replaces the *mechanical execution* of the skill's steps. It
follows the same steps in the same order, but adapts the one step that
depended on an LLM's judgment: where the skill asks the user which version to
use on a mismatch, the script (having no one to ask) aborts instead. See
"Version mismatch" under Components.

## Architecture

Add `scripts/release.mjs`, wired up as `"release": "node scripts/release.mjs"`
in `package.json`, following the pattern already established by
`scripts/verify-manifest-references.mjs` (`pnpm verify:manifest-references`).

The script name is `release`, not `publish` — `pnpm publish` collides with
pnpm's own built-in registry-publish command, so a bare-name script called
`publish` would never actually run (pnpm's shorthand only dispatches to a
package script when the name doesn't collide with one of pnpm's own
commands). `pnpm release` has no such collision.

The script runs as a single top-to-bottom sequence of steps, in the same
order as the skill:

1. Verify the build.
2. Confirm the worktree is clean, `main` is the current branch, and it is
   synced with `origin/main`.
3. Bump the patch version in both `plugin.json` files and commit.
4. Push to `origin/main`.

There are no flags (no `--dry-run` or similar) and no subcommands — running
`pnpm release` performs the full sequence, matching the skill.

Each step is a small function. `main()` calls them in order and stops at the
first failure: it prints a one-line reason to `stderr`, sets
`process.exitCode = 1`, and returns without running later steps. On success,
the script prints a final confirmation line naming the new version and
confirming the push.

## Components

- **`runCommand(cmd, args)`** — thin wrapper over Node's `spawnSync` with
  `stdio: "inherit"`, used for steps whose only job is to succeed or fail
  visibly (`pnpm verify`, `git fetch`, `git add`, `git commit`, `git push`).
  The wrapped command's own output streams live. A launch error (e.g. the
  executable isn't found), a non-null signal, or a non-zero/`null` exit
  status all count as failure.

- **`captureCommand(cmd, args)`** — a second wrapper over `spawnSync`, used
  for steps that need to read a command's stdout (`git rev-parse`,
  `git rev-list`). Captures stdout instead of inheriting it; the same
  failure rules as `runCommand` apply. On failure it does not have a visible
  subprocess to point to, so it prints the captured stderr itself before
  aborting.

- **`verifyBuild()`** — runs `pnpm verify` via `runCommand`. A non-zero exit
  aborts the script; no additional message is printed beyond what `pnpm
  verify` itself already produced.

- **`checkMainSynced()`** — runs, in order:
  - `git status --porcelain` via `captureCommand`, and aborts with
    `"worktree has uncommitted changes — commit or stash first."` if the
    output is non-empty. This guarantees the later version-bump commit
    contains only the two `plugin.json` changes, never unrelated
    staged/unstaged work.
  - `git rev-parse --abbrev-ref HEAD` via `captureCommand`, and aborts with a
    one-line message if the result is not `main`.
  - `git fetch origin main` via `runCommand`.
  - `git rev-list --left-right --count origin/main...HEAD` via
    `captureCommand`, parsing the two counts (`<left> <right>`). Checked in
    this order:
    1. Both counts `> 0` → diverged. Abort: "main has diverged from
       origin/main — reconcile first."
    2. Left count (incoming from origin) `> 0` → behind. Abort: "main is
       behind origin/main — pull/rebase first."
    3. Otherwise → synced, continue.

    Checking "diverged" before "behind" matters: a diverged branch also has
    a positive left count, and would be misreported as merely "behind" if
    checked in the other order.

  The branch/sync checks mirror the skill's logic exactly; the worktree
  check is an addition the skill doesn't have, since an agent following the
  skill's steps would naturally notice unrelated dirty state, but a script
  won't unless it checks explicitly.

- **`bumpPatchVersion()`** — reads `plugin/.claude-plugin/plugin.json` and
  `plugin/.codex-plugin/plugin.json`, parses their `version` fields, and:
  - Requires each `version` field to be a string matching
    `^\d+\.\d+\.\d+$` (three dot-separated non-negative integers, e.g.
    `"0.0.3"`). A missing field, non-string value, or value not matching
    this pattern aborts with a message naming the offending file and value.
    Pre-release/build-metadata suffixes (e.g. `-beta`, `+build`) are not
    accepted — this is out of scope; see below.
  - Aborts with an error (no interactive prompt) if the two versions
    disagree, reporting both values and telling the user to fix the
    mismatch manually. This is the one place the script's behavior departs
    from the skill's, which asks the user interactively; see Goal.
  - Otherwise computes the incremented patch version (`"0.0.3"` →
    `"0.0.4"`), writes both files, and runs `git add` + `git commit -m
    "Bump version to <new-version>"` via `runCommand`.

  The pure version-parsing/incrementing/mismatch-check logic (accepting two
  version strings, returning either the new version or a description of why
  it can't proceed) lives in a separate module, `scripts/release-version.mjs`,
  exporting plain functions with no subprocess or filesystem access —
  mirroring how `manifest-references.mjs` holds logic that
  `verify-manifest-references.mjs` merely invokes. `scripts/release.mjs`
  imports and calls it; `tests/release-version.test.mjs` imports and tests
  it directly, without ever loading `release.mjs` (which runs `main()`
  unconditionally on load).

- **`pushToOrigin()`** — runs `git push origin main` via `runCommand`. If it
  fails, the script prints an explicit warning that the version-bump commit
  was already made locally but not pushed, and that the user should push it
  manually (e.g. `git push origin main`) once the underlying problem is
  resolved. No automatic retry or rollback is attempted — the earlier sync
  check makes this failure rare in practice, since it only happens after
  `main` was already confirmed synced with `origin/main` moments earlier
  (e.g. a network error, or someone else pushing to `main` in that window).

`main()` calls `verifyBuild()`, `checkMainSynced()`, `bumpPatchVersion()`,
then `pushToOrigin()`, in that order — matching the skill's ordering so that
the sync check always runs before any commit is made.

## Data Flow

No data flows between steps beyond the computed version string, which
`bumpPatchVersion()` produces and uses in its own commit message and which
the final success message reuses. Each step inspects repository/filesystem
state directly rather than being passed state computed by a previous step.

## Error Handling

Two kinds of failure produce different output:

- **Script-level validation failures** — wrong branch, sync check, missing
  or malformed version fields, version mismatch — print a single clear line
  to `stderr`, e.g. `"main is behind origin/main — pull/rebase first."` or
  `"plugin.json versions disagree: 0.0.3 vs 0.0.4"`. No subprocess is
  involved, so there is nothing else to show.
- **Subprocess failures** — `pnpm verify`, `git fetch`, `git commit`
  exiting non-zero — add no message of their own. The subprocess's native
  (possibly multi-line) output, already visible via `runCommand`'s inherited
  stdio, is the diagnostic. `git push` is the one exception: on failure the
  script adds the explicit warning described under `pushToOrigin()`, because
  at that point a local commit has already been made and the user needs to
  know it wasn't pushed.

In both cases, `process.exitCode` is set to `1` and `main()` returns
immediately; no later step runs. On success, the script prints a final line
reporting the new version and confirming the push, matching the skill's
final "report the result to the user" step.

## Testing

The git/pnpm-shelling parts (`runCommand`, `captureCommand`,
`checkMainSynced`, `pushToOrigin`) are not practically unit-testable without
mocking subprocesses, and won't have automated tests — consistent with
there being no test for `verify-manifest-references.mjs`'s own orchestration
today. Since `pnpm release` itself exercises this script on every real
release, this orchestration logic is effectively verified in practice each
time it runs.

`scripts/release-version.mjs` (the pure version-parsing/increment/
mismatch-check module described under Components) gets a `node --test` unit
test at `tests/release-version.test.mjs`, following the existing
`tests/manifest-references.test.mjs` pattern, covering: valid bump, matching
versions, mismatched versions, and malformed/missing version strings. No
broader integration test (e.g. against a scratch git repository) is
planned.

## Out of Scope

- Flags such as `--dry-run`.
- Interactive prompts of any kind.
- Pre-release or build-metadata version suffixes (`-beta`, `+build`, etc.) —
  only plain `x.y.z` versions are supported.
- Retiring or modifying the `publish-branch` skill itself.
