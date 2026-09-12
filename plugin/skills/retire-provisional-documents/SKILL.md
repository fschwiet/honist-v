---
name: retire-provisional-documents
description: Retire provisional documentation after making its consumers self-contained and preserving only durable domain language and decision rationale.
disable-model-invocation: true
---

# Retire Provisional Documents

Retire every file under these repository-relative directories:

- `docs/superpowers/`
- `docs/honist-v/`
- `docs/matt-pocock/`

## Verify a clean environment

Refuse to continue if there are changes to tracked files in either the index or working tree.

## Inventory the retirement set

1. Enumerate every file currently beneath the three retirement directories, including untracked and hidden files. Sort the repository-relative paths and show the user the complete retirement set before reading or editing anything else: one path per line, with no summarized entries. This list is the retirement manifest.
2. If any files in the retirement manifest are untracked warn the user and ask for their confirmation before proceeding.
3. If the manifest is empty, report that there is nothing to retire and stop without committing.

Completion criterion: every file that this run could retire has appeared in the manifest, and the user can distinguish any untracked file whose deletion Git could not recover.

## Load the durable context

Read the complete [`domain-modeling` skill](../mattpocock-skills/engineering/domain-modeling/SKILL.md), including the context and ADR formats it directs you to use. In the target repository, read `CONTEXT-MAP.md` when present, every repository `CONTEXT.md`, and every current ADR located by the domain-modeling rules.

Use these sources to decide where durable information belongs. The provisional documents may reveal a claim or rationale to investigate, but they are not evidence that a current-state claim is true.

Completion criterion: the repository's complete domain vocabulary and current decision archive have been read before any replacement is proposed.

## Remove dependencies on the manifest

Search every surviving repository file for references to the retirement directories or their files. Account for direct paths, relative links, directory-level links, and references identifiable only by a target filename. Inspect candidates rather than treating text-search matches as findings.

Classify a reference by its purpose. A **maintenance reference** defines where or how provisional files are created, organized, found, read, or updated; the path is part of the surviving workflow rather than a dependency on the current contents. Preserve maintenance references when that workflow remains current, even when they name a retirement directory. For example, an issue-tracker guide may continue to define `docs/matt-pocock/` as its storage location. Treat a reference that expects information from a particular manifest file as a dependency to remove.

For every real reference, verify the information its consumer still needs against current code, configuration, tests, and surviving documentation. Propose the smallest change that lets the consumer stand on its own:

- In code comments and code-facing documentation, retain only the non-obvious reason the code behaves as it does.
- In user and agent documentation, retain common operational details that the reader needs there or that have no durable authoritative home. Point to an existing stable source when it already owns the detail and that stable source's location is unexpected.
- Put canonical domain terms and boundaries in the applicable `CONTEXT.md`.
- Put a design decision in an ADR only when it passes the domain-modeling skill's ADR test. Preserve the trade-off and rationale, not project chronology.
- Remove a reference without replacement when its consumer needs none of the referenced information.

For each proposed change, record the surviving file affected, the reference being removed, the exact replacement or deletion, its authoritative evidence, and why that destination is appropriate. Every found reference must map to a proposed change or a documented no-change conclusion identifying a current maintenance reference.

Completion criterion: there is an evidence-backed disposition for every reference from a surviving file to a retirement path, and every retained reference is a current maintenance reference.

## Agree on and commit the cleanup

If no surviving file depends on the manifest and every path reference is a current maintenance reference, tell the user this phase is a no-op. Create no empty commit and continue to the retirement phase.

Otherwise, read and follow the complete [`grilling` skill](../mattpocock-skills/productivity/grilling/SKILL.md). Treat the proposed cleanup as its design tree. Explain the evidence and recommend a resolution for each change; investigate facts yourself and reserve questions for decisions. Editing begins only after the user confirms shared understanding for the complete cleanup set.

Apply exactly the approved set without modifying, renaming, or deleting any file in the retirement manifest. Re-run the reference search and relevant repository checks, then review the diff. Stage only the approved cleanup changes and commit them using the repository's commit conventions. Advance only when every surviving path reference is a verified maintenance reference; otherwise revise the proposal with the user.

Completion criterion: either the phase was a verified no-op, or a focused cleanup commit exists and every surviving reference to a retirement path is a current maintenance reference.

Only after meeting that criterion, review every file in the retirement manifest in the context of the complete manifest, the repository's `CONTEXT.md` files, its current ADRs, and the `domain-modeling` skill.

## Review what deserves a durable home

Account for every manifest file and classify its useful information:

- Propose canonical terms and domain boundaries for the applicable `CONTEXT.md`. Keep that file a glossary without implementation details.
- Propose a new or updated ADR only for a decision that passes the domain-modeling skill's ADR test. Preserve why the current decision was made: the alternatives, trade-off, and constraints that still explain it.
- Discard status reports, implementation narration, superseded plans, chronology, and descriptions of current behavior that the repository itself makes discoverable.
- Avoid duplicating information already owned by a surviving authoritative source.

For every proposed ADR creation or update, inspect the code and surviving documentation that bear on its claims. Reconcile contradictions before proposing text. For every proposed `CONTEXT.md` change, verify that the terminology describes the current domain consistently.

Build a proposed retirement set that names, for every manifest file, the exact information to migrate and its destination or states that nothing in the file merits preservation. Include the complete deletion manifest.

Completion criterion: every file to be deleted has been reviewed, every preservation proposal has current evidence and one durable home, and the deletion manifest matches the target directories' current contents.

## Agree on the retirement

Read and follow the complete `grilling` skill again. Start a new design tree covering every proposed `CONTEXT.md` or ADR change and deletion of the exact manifest. Group independent decisions into the same frontier round, show the evidence for each proposal, and give a recommended resolution.

Update the proposal as answers reshape it. Do not edit or delete files until the user confirms shared understanding for all durable-context changes and the complete deletion manifest.

Completion criterion: the user has approved an exact change set and every file slated for deletion has appeared in that approval.

## Apply and commit the retirement

Apply exactly the approved `CONTEXT.md` and ADR changes, then delete every file in the approved manifest. Do not delete similarly named directories or files outside it.

Verify that:

- each changed or created ADR follows the domain-modeling format and agrees with current code and surviving documentation;
- each changed `CONTEXT.md` follows the domain-modeling format and contains domain language rather than implementation detail;
- no surviving reference depends on a retired manifest file, and every retained retirement-path reference is a current maintenance reference;
- the three retirement directories contain no files; and
- the diff contains only approved durable-context changes and manifest deletions.

Run relevant repository checks. Stage only the approved changes and deletions, then create one coherent retirement commit using the repository's commit conventions. If the approved set contains no durable-context changes, create the deletion-only commit. Report any deleted untracked files separately because they cannot appear in the commit.

Completion criterion: every approved manifest file is absent, the relevant checks pass, and the retirement commit contains no unrelated changes.
