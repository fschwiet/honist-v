---
name: consolidate-adrs
description: Reconcile an ADR archive with the repository's current design and its surviving rationale.
disable-model-invocation: true
---

# Consolidate ADRs

Reconcile the ADR archive into a concise account of the repository's current design and the rationale that still explains it. Historical detail earns a place only when it helps a future reader understand why the current design exists.

## Prepare the review

1. Read the complete [`domain-modeling` skill](../mattpocock-skills/engineering/domain-modeling/SKILL.md) and the ADR format it points to. Use its context-map rules to locate every applicable `CONTEXT.md` and ADR archive. If the repository has no context or ADR archive, report that this skill has nothing to consolidate.
2. Read the applicable `CONTEXT.md` files and every current ADR before judging any one ADR. Treat `CONTEXT.md` as vocabulary and domain-boundary context; the review targets are the ADRs.

Completion criterion: every ADR has been read in the context of the complete archive and the applicable domain context.

## Build the change set

Review every ADR for:

- claims that contradict another ADR or the domain language;
- decisions that another ADR corrects, updates, or subsumes;
- duplicated rationale or current-state descriptions with more than one home;
- historical narration that does not justify the current design; and
- links or other references to material under `docs/superpowers/`, `docs/honist-v/`, or `docs/mattpocock/`.

For a corrected, updated, or subsumed decision, choose one authoritative ADR to carry the consolidated current decision and its useful rationale. Update that ADR and remove stale or duplicate claims from the others. Retain a brief account of an earlier choice only when it explains the current design. When an ADR has no useful current decision or rationale left, propose deleting it.

Replace each dependency on a provisional document with the specific context, decision, trade-off, or constraint the ADR needs to stand on its own. Verify that information against the repository rather than copying the provisional document's account. The provisional documents themselves are outside this review's change set.

After identifying a candidate change, inspect only the implementation, configuration, and tests that bear on the affected ADR's claims. Bound repository inspection to the evidence needed to verify the content that ADR would keep, rewrite, move, or remove. Current repository behavior, plus user-confirmed constraints that cannot live in code, is the evidence for its present-tense claims. Claims in ADRs outside the intended change set are outside this correctness review.

Record every intended change with:

- the ADR files it changes or removes;
- the contradiction, stale statement, or provisional reference being resolved;
- the repository evidence for the proposed current account;
- the exact information to keep, move, rewrite, or remove; and
- any historical context retained and why it still justifies the design.

Completion criterion: every finding is either represented by an intended change or explicitly recorded as needing no change, and every current-state claim in the intended change set has repository evidence or a user-confirmed non-code constraint.

## Reach agreement

Before editing, read and follow the complete [`grilling` skill](../mattpocock-skills/productivity/grilling/SKILL.md). Treat the intended changes as its design tree. Ask about every intended change, grouping independent decisions into the same frontier round, and include the evidence and your recommended resolution. Investigate facts yourself; reserve questions for decisions. Recompute the change set when an answer affects other ADRs.

Editing may begin only after the user confirms shared understanding for every intended change. Exclude rejected changes from the approved set.

## Apply and commit

Apply exactly the approved set. Re-read the complete resulting ADR archive and verify that:

- content changed by the approved set agrees with the current repository and applicable domain language;
- no contradictory or stale account addressed by the approved set remains;
- each retained historical detail justifies the current design;
- the ADRs are self-contained and contain no references to `docs/superpowers/`, `docs/honist-v/`, or `docs/mattpocock/`; and
- the files still follow the `domain-modeling` ADR format.

Run relevant repository checks. Review the diff, stage only the approved ADR changes, and commit them without including unrelated worktree changes. Use one coherent consolidation commit unless the approved change set or repository conventions require separate commits. If the approved set is empty, report that outcome without creating an empty commit.

Completion criterion: all approved changes pass the final archive review and relevant checks, and the resulting ADR-only commit or commits exist.
