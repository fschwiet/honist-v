---
name: streamlined-setup-matt-pocock-skills
description: 'Configure this repo for the engineering skills using one fixed set of choices: local-markdown issue tracker, default triage labels, single-context domain docs. Overwrites any earlier setup. Run once per repo.'
disable-model-invocation: true
---

# Streamlined Setup Matt Pocock Skills

Write the per-repo configuration the engineering skills assume. This skill produces the same artifacts as `/setup-matt-pocock-skills`, but every choice is fixed in advance: it inspects nothing about the repo, asks nothing, and overwrites whatever an earlier setup left behind. Two repos configured by this skill end up byte-identical.

**Ask no questions. Inspect nothing beyond the gate in step 1. Write only the files named below, using the exact text given. Do not commit.**

## The fixed configuration

| Decision           | Value                                                         |
| ------------------ | ------------------------------------------------------------- |
| Issue tracker      | Local markdown files under `docs/matt-pocock/`                |
| Triage labels      | The five canonical roles, each used verbatim as its own label |
| Domain docs        | Single-context: `CONTEXT.md` + `docs/adr/` at the repo root   |
| Agent instructions | `AGENTS.md`, with `CLAUDE.md` importing it                    |

Never adapt these to the repo. A repo with a GitHub remote still gets the local-markdown tracker; a monorepo still gets single-context. Adapting is the behaviour this skill exists to remove.

## 1. Gate on a clean working tree

The skill overwrites files without asking, so the user's ability to review `git diff` is the only safety net. Protect it.

Run `git rev-parse --is-inside-work-tree`. If it fails, stop:

> Not a git repository. This skill overwrites files and relies on `git diff` for review. Run it inside a repo.

Run `git status --porcelain`. If the output is non-empty, stop:

> Working tree is not clean. Commit or stash your changes, then re-run this skill so its edits land in a reviewable diff on their own.

Untracked files count as dirty. Do not offer to stash, and do not proceed on the user's say-so; they can stash and re-run.

## 2. Write the config docs

Copy these three templates to `docs/agents/`, creating the directory if needed. Copy them **verbatim** — no per-repo tailoring, no rewrapping. Overwrite the destination if it already exists.

| Template                                           | Destination                    |
| -------------------------------------------------- | ------------------------------ |
| [issue-tracker-local.md](./issue-tracker-local.md) | `docs/agents/issue-tracker.md` |
| [domain.md](./domain.md)                           | `docs/agents/domain.md`        |
| [triage-labels.md](./triage-labels.md)             | `docs/agents/triage-labels.md` |

Write `triage-labels.md` unconditionally, whether or not the `triage` skill is installed.

Leave every other file in `docs/agents/` alone. Do not create `docs/matt-pocock/`, `CONTEXT.md`, or `docs/adr/`; the skills that own those create them when they first have something to put there.

## 3. Point AGENTS.md and CLAUDE.md at the config

This is the exact block. Write it character for character.

```markdown
## Agent skills

### Issue tracker

Issues, specs, and wayfinder maps live as markdown files under `docs/matt-pocock/`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, used verbatim as `Status:` values. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
```

**In `AGENTS.md`:** if an `## Agent skills` section already exists, replace it in place — same position in the file, surrounding sections untouched. Otherwise append the block at the end. If `AGENTS.md` doesn't exist, create it containing the block alone, with no `#` heading above it.

**In `CLAUDE.md`:**

- If `CLAUDE.md` is a symlink to `AGENTS.md`, leave it completely alone. It is already the alias; writing through the link would clobber `AGENTS.md`.
- Otherwise, if it contains an `## Agent skills` section, delete that section. An earlier setup put it there, and two live copies of this configuration can disagree. Leave the rest of the file untouched.
- Otherwise, if it does not already import `AGENTS.md`, add `@AGENTS.md` as the first line, followed by a blank line.
- If `CLAUDE.md` does not exist, create it containing exactly `@AGENTS.md`.

## 4. Report

List the files written, then stop:

> Wrote `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, `docs/agents/triage-labels.md`, `AGENTS.md`, `CLAUDE.md`. Review with `git diff` and commit when you're happy.

Name only the files you actually touched. Don't commit, and don't summarise the configuration back — the diff shows it.
