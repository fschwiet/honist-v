---
name: publish-branch
description: Publish the main branch — verify the build, confirm main is synced with origin/main, bump the patch version in both plugin.json files, commit, and push.
disable-model-invocation: true
---

# Publish Branch

Publish the current work by verifying the build, bumping the version, and pushing to `origin/main`.

Perform these steps in order. **If any check fails, stop immediately and report the failure — do not continue to a later step.**

## 1. Verify the build

Run `pnpm verify`. If it exits non-zero, abort and show the user the failing output. Do not proceed.

## 2. Confirm the branch is main and synced with origin/main

- Confirm the current branch is `main` (`git rev-parse --abbrev-ref HEAD`). If not, abort.
- Run `git fetch origin main`.
- Confirm local `main` is caught up with `origin/main`: the local HEAD must equal or be ahead of `origin/main`, with no incoming commits. Compare with `git rev-list --left-right --count origin/main...HEAD`.
  - If the left count (incoming from origin) is greater than 0, the branch is behind — abort and tell the user to pull/rebase first.
  - If there are diverged commits on both sides, abort and tell the user to reconcile first.

## 3. Bump the patch version and commit

The two files to update are:

- `plugin/.claude-plugin/plugin.json`
- `plugin/.codex-plugin/plugin.json`

Both should hold the same version. Read both, confirm they match, then increment the smallest (patch) component — e.g. `0.0.3` → `0.0.4`. If they disagree, stop and ask the user which version to use.

Update both files, then commit them together:

```sh
git add plugin/.claude-plugin/plugin.json plugin/.codex-plugin/plugin.json
git commit -m "Bump version to <new-version>"
```

## 4. Push

Run `git push origin main` and report the result to the user.
