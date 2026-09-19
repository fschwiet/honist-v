# Changes to the Matt Pocock skills since `ccd6ca7`

This document lists commits after `ccd6ca7` that changed files under
`plugin/skills/mattpocock-skills`. The commits are listed chronologically.

## `2d9250a` — 2026-08-24

Added a peer-review stage to `to-spec`. The draft is reviewed with
`prompt-a-peer-high` for clarity, completeness, ambiguity, and hidden
assumptions before it is published.

## `9ed011d` — 2026-08-24

Added a peer-review stage to `to-tickets`, covering spec coverage, ambiguity,
and ticket decomposition. Added `to-tickets/ticket-review-prompt.md` with the
review criteria and calibration guidance.

## `3df3794` — 2026-08-24

Renamed the `code-review` skill to `code-review-of-changeset` and updated its
cross-references. Narrowed its trigger to source-code changesets, explicitly
excluding documentation-only diffs. Changed the two review axes to use
`prompt-a-peer-medium` sequentially, added a guard against recursive
invocation, and updated the related `ask-matt`, `implement`, and `tdd`
references.

## `19eed7f` — 2026-08-25

Synchronized selected `agents/openai.yaml` metadata: renamed the code-review
display name to “Code Review Of Changeset” and adjusted the grill-with-docs
display name and description. Added `sync-skills-openai-yaml` to the
productivity skill index.

## `7e8884a` — 2026-08-26

Added the streamlined setup workflow and deprecated the original
`setup-matt-pocock-skills` workflow in place. The original setup skill now
directs users to the replacement, while its setup reference files were
removed. Updated local ticket paths from `.scratch/<feature>/issues/` to
`docs/matt-pocock/<feature>/issues/`, and adjusted related path references in
`ask-matt` and `code-review-of-changeset`.

## `1cbacfb` — 2026-08-26

Updated `implement` so it sets a ticket’s status to `resolved` and commits the
ticket update together with the implementation.

## `7efa0fa` — 2026-08-31

Reworked the `implement` sequence so it runs the full verification pipeline
before review, runs `code-review-of-changeset` after verification, updates the
ticket status afterward, and commits last.

## `59d812d` — 2026-08-31

Removed the user-facing “Quiz the user” step from `to-tickets`. Ticket
breakdown now proceeds directly to peer review, followed by publication.

## `452eb4c` — 2026-08-31

Changed `implement` from directly implementing user work to orchestrating
tickets sequentially through agents, one unblocked ticket at a time. Added
starting-commit tracking, per-agent verification guidance, a final full
verification pass, and a review/fix/reverification sequence before resolving
tickets and committing.

## `0d0e82b` — 2026-09-05

Removed the peer-review stage from `to-tickets`; the skill now publishes the
ticket breakdown directly after creating it.

## `9733a57` — 2026-09-09

Clarified `wayfinder`’s local workflow: research agents commit their findings,
the mapping session stops and commits its changes, and the old assumption that
other sessions edit an external tracker concurrently was removed.

## `acd3a84` — 2026-09-12

Updated `implement` so each agent commits its work before returning.

## `639e9dd` — 2026-09-12

Changed the agent handoff state in `implement`: agents now mark tickets
`ready-for-review` before committing, and the final verification pass begins
once all tickets have been committed in that state, rather than treating them
as resolved immediately.
