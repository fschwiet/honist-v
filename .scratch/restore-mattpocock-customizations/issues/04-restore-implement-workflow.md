# 04: Restore the latest implement workflow

**What to build:** Restore the final customized `implement` orchestration behavior as one coherent workflow, combining its overlapping historical updates.

**Reference commits:** `3df3794` (code-review reference), `1cbacfb`, `7efa0fa`, `452eb4c`, `acd3a84`, `639e9dd` (successive implement workflow updates)

**Blocked by:** 01: Restore code-review-of-changeset; 02: Remove the replaced Matt Pocock setup skill

**Status:** resolved

- [x] Tickets are delegated sequentially, one unblocked ticket at a time.
- [x] Agents verify their work, commit it, and leave tickets ready for review rather than resolved.
- [x] The full verification and review/fix/reverification sequence runs before final resolution and commit.
- [x] The workflow references the restored code-review skill and current local ticket conventions.
