# Publish Script Design

## Goal

Add a `pnpm publish` script that performs the release steps currently
described by the `publish-branch` skill, without requiring an LLM agent to
interpret and execute those steps by hand. The script codifies the skill's
behavior as plain Node code: verify the build, confirm `main` is synced with
`origin/main`, bump the patch version in both `plugin.json` files, commit,
and push.

The script replaces the *mechanical execution* of the skill's steps. It does
not change what those steps are; it is a direct port of the skill's current
behavior into runnable code.

## Architecture

Add `scripts/publish.mjs`, wired up as `"publish": "node scripts/publish.mjs"`
in `package.json`, following the pattern already established by
`scripts/verify-manifest-references.mjs` (`pnpm verify:manifest-references`).

The script runs as a single top-to-bottom sequence of steps, in the same
order as the skill:

1. Verify the build.
2. Confirm `main` is the current branch and is synced with `origin/main`.
3. Bump the patch version in both `plugin.json` files and commit.
4. Push to `origin/main`.

There are no flags (no `--dry-run` or similar) and no subcommands — running
`pnpm publish` performs the full sequence, matching the skill.

Each step is a small function. `main()` calls them in order and stops at the
first failure: it prints a one-line reason to `stderr`, sets
`process.exitCode = 1`, and returns without running later steps. On success,
the script prints a final confirmation line naming the new version and
confirming the push.

## Components

- **`runCommand(cmd, args)`** — thin wrapper over Node's `spawnSync`. Inherits
  stdio so the wrapped command's own output streams live (matching how
  `pnpm verify`'s output is seen today). Returns the exit status so callers
  can branch on success/failure.

- **`verifyBuild()`** — runs `pnpm verify` via `runCommand`. A non-zero exit
  aborts the script; no additional message is printed beyond what `pnpm
  verify` itself already produced.

- **`checkMainSynced()`** — runs, in order:
  - `git rev-parse --abbrev-ref HEAD`, and aborts if the result is not `main`.
  - `git fetch origin main`.
  - `git rev-list --left-right --count origin/main...HEAD`, parsing the two
    counts to detect "behind" (incoming commits present) or "diverged"
    (commits on both sides). Aborts in either case, with a message telling
    the user to pull/rebase or reconcile first.

  This mirrors the skill's sync-check logic exactly.

- **`bumpPatchVersion()`** — reads `plugin/.claude-plugin/plugin.json` and
  `plugin/.codex-plugin/plugin.json`, parses their `version` fields, and:
  - Aborts with an error (no interactive prompt) if the two versions
    disagree, reporting both values and telling the user to fix the mismatch
    manually.
  - Otherwise computes the incremented patch version (`"0.0.3"` →
    `"0.0.4"`), writes both files, and runs `git add` + `git commit -m
    "Bump version to <new-version>"`.

  The pure version-parsing/incrementing/mismatch-check logic is factored out
  into a standalone function so it can be unit tested without shelling out.

- **`pushToOrigin()`** — runs `git push origin main`.

Like `verifyBuild()`, the `git commit` and `git push` invocations inside
`bumpPatchVersion()` and `pushToOrigin()` rely on `runCommand`'s exit-status
check: any failure (e.g. a rejected push, a commit hook failure) aborts the
script with `runCommand`'s inherited stdio already showing the underlying
git error, with no additional message layered on top.

`main()` calls `verifyBuild()`, `checkMainSynced()`, `bumpPatchVersion()`,
then `pushToOrigin()`, in that order — matching the skill's ordering so that
the sync check always runs before any commit is made. If the sync check
fails, no commit has been made yet, so there is nothing to roll back.

## Data Flow

No data flows between steps beyond the computed version string, which
`bumpPatchVersion()` produces and uses in its own commit message and which
the final success message reuses. Each step inspects repository/filesystem
state directly rather than being passed state computed by a previous step.

## Error Handling

On failure, a step prints a single clear line to `stderr`, for example:

- `"main is behind origin/main — pull/rebase first."`
- `"main has diverged from origin/main — reconcile first."`
- `"plugin.json versions disagree: 0.0.3 vs 0.0.4"`

`process.exitCode` is set to `1` and `main()` returns immediately; no later
step runs. On success, the script prints a final line reporting the new
version and confirming the push, matching the skill's final "report the
result to the user" step.

## Testing

The git/pnpm-shelling parts (`runCommand`, `checkMainSynced`, `pushToOrigin`)
are not practically unit-testable without mocking subprocesses, and won't
have automated tests — consistent with there being no test for
`verify-manifest-references.mjs`'s own orchestration today. Since `pnpm
publish` itself exercises this script on every real release, this
orchestration logic is effectively verified in practice each time it runs.

The pure version-parsing/increment/mismatch-check logic used by
`bumpPatchVersion()` will be extracted into a standalone function with a
`node --test` unit test under `tests/`, following the existing
`tests/manifest-references.test.mjs` pattern. No broader integration test
(e.g. against a scratch git repository) is planned.

## Out of Scope

- Flags such as `--dry-run`.
- Interactive prompts of any kind.
- Rolling back a commit already made if a later step fails (the step
  ordering makes this unreachable: the sync check always precedes the
  commit).
- Retiring or modifying the `publish-branch` skill itself.
