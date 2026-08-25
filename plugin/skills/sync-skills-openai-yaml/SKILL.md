---
name: sync-skills-openai-yaml
description: Sync every skill's agents/openai.yaml with its SKILL.md — display name, short description, and implicit-invocation policy.
disable-model-invocation: true
---

# Sync Skills OpenAI YAML

Claude Code reads a skill's invocation policy from `SKILL.md` frontmatter (`disable-model-invocation`). Codex reads the same policy from a sibling `agents/openai.yaml`. The two drift independently — a skill can gain or flip `disable-model-invocation` in `SKILL.md` without anyone touching the Codex file, or a new skill can ship with no `agents/` folder at all. This skill closes that gap for every `SKILL.md` in the project, using [`ask-matt/agents/openai.yaml`](../../engineering/ask-matt/agents/openai.yaml) as the reference shape.

## Process

1. **Inventory.** Find every `SKILL.md` under the project that isn't gitignored (`git ls-files` / `git check-ignore`, not a hardcoded exclude list — this is what actually keeps caches, `node_modules`, and similar out without needing to know their paths in advance). Outside a git repo, fall back to excluding `node_modules` and `.git`. For each, read the frontmatter: `name`, `description`, `disable-model-invocation`.

   Completion criterion: every `SKILL.md` path in the project is listed with those three values.

2. **Compute target state.** The paired file is `agents/openai.yaml` in a folder sibling to `SKILL.md`. For each skill:
   - `interface.display_name`: Title Case of `name` (hyphens → spaces). Known acronyms (`TDD`, `ADR`, `YAML`, `PR`, ...) keep their conventional capitalization rather than generic title-casing.
   - `interface.short_description`: a short (~40 character), human-facing paraphrase of `description` — reworded, not copied verbatim or truncated mid-word.
   - `policy.allow_implicit_invocation`: `false` when `disable-model-invocation: true` is set in `SKILL.md`. When `disable-model-invocation` is absent, omit the `policy` block entirely — the schema default is `true`, so an explicit `true` is a no-op and shouldn't be written.

   Compare against whatever the file currently holds (nothing, if it doesn't exist). A missing file, a missing or wrong `interface` block, or a `policy` block that doesn't match the rule above are all findings. Leave any other existing field alone (e.g. `interface.default_prompt`) — this skill only owns `interface.display_name`, `interface.short_description`, and `policy.allow_implicit_invocation`.

   Completion criterion: every skill from Step 1 is marked create, fix (naming what's wrong), or already-correct.

3. **Apply.** For every skill marked create or fix, write or edit `agents/openai.yaml`, creating the `agents/` folder when needed. Single-quote YAML string values, matching the reference file.

   Completion criterion: every `SKILL.md` in the inventory has a sibling `agents/openai.yaml` whose `interface` and `policy` match Step 2's target state.

4. **Report.** Show the user a table: skill → created / fixed (what changed) / already correct. Flag any skill that lives inside a directory synced from an upstream source (e.g. a vendored `obra/superpowers`-style import) — a future upstream sync can overwrite the file this step just wrote or fixed, so it's worth a note even though it's not a reason to skip the fix now.
