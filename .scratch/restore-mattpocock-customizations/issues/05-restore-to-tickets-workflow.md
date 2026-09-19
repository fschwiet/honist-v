# 05: Restore the latest to-tickets workflow

**What to build:** Restore the final customized ticket-decomposition workflow while excluding all peer-review additions.

**Reference commits:** `7e8884a` (local ticket path), `59d812d` (remove user quiz), `0d0e82b` (remove peer-review stage); `9ed011d` is intentionally excluded because it added peer review.

**Blocked by:** 02: Remove the replaced Matt Pocock setup skill

**Status:** ready-for-review

- [x] Tickets use the customized local location and dependency-oriented numbering.
- [x] The workflow publishes the ticket breakdown without a user quiz or peer-review stage.
- [x] No `prompt-a-peer-*` invocation or dedicated peer-review prompt file is introduced.
