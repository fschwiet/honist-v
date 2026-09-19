# 01: Restore code-review-of-changeset

**What to build:** Restore the repository’s customized source-code changeset review workflow without reinstating any `prompt-a-peer-*` review behavior.

**Reference commits:** `3df3794` (rename and scope), `19eed7f` (metadata), `7e8884a` (path references)

**Blocked by:** None (can start immediately)

**Status:** ready-for-review

- [x] The renamed `code-review-of-changeset` skill is available and the former `code-review` skill is no longer the active name.
- [x] The skill is limited to source-code changesets and explicitly declines documentation-only diffs.
- [x] The customized parallel sub-agent workflow is not applied.
- [x] No `prompt-a-peer-*` invocation or peer-review prompt file is introduced.
