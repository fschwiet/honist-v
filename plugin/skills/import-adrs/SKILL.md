---
name: import-adrs
description: Ingest a folder of past design docs and propose a draft ADR set for review — a resumable, batch back-fill of the ADR archive from stale, diverged specs and plans.
disable-model-invocation: true
---

Take a folder of old design documents — timestamped specs, plans, RFCs that have diverged from the code — and back-fill the ADR archive from them. Where `/domain-modeling` captures decisions one at a time as you design, this is the bulk pass: read the pile, distil the decisions still worth recording, and propose them as **drafts** the user accepts or rejects. It never writes into `docs/adr/` without sign-off.

Two things this skill does **not** own — read them from `/domain-modeling` rather than restating:

- The ADR **template and the three-part test** (hard to reverse · surprising without context · a real trade-off) live in [`../domain-modeling/ADR-FORMAT.md`](../domain-modeling/ADR-FORMAT.md). That test is the gate every candidate passes through here.
- Where ADRs live and how they're numbered — same file.

## The ledger

The import is **resumable**: a run can span sessions, and re-invoking picks up where the last left off. State lives in `docs/adr/_drafts/IMPORT-LOG.md` — one row per source document:

```md
# ADR import log

Source folder: <path>

| Source document                | Status   | Cleanup | Drafts produced                        |
| ------------------------------ | -------- | ------- | -------------------------------------- |
| docs/plans/2024-03-checkout.md | reviewed | cleanup | event-sourced-orders, drop-legacy-cart |
| docs/plans/2024-05-payments.md | pending  | kept    | —                                      |
```

`Status` is `pending` or `reviewed`. A document is only marked `reviewed` once its decisions have been extracted and drafted — so the pending rows are exactly the work remaining. `Cleanup` records the source document's retirement lifecycle:

- `kept` — retain the document after the import.
- `cleanup` — delete it after the accepted ADRs are committed.
- `removed` — its scheduled deletion has landed.

Rows marked `removed` remain in the ledger as history, but are no longer active sources: exclude them when resuming extraction, reconciling the source folder, or assembling review provenance. Drafts themselves accumulate in `docs/adr/_drafts/` as `<slug>.md` (no number yet; numbers are assigned on acceptance).

## Terms it trips over

Reading every document closely surfaces the project's **vocabulary** as a byproduct — and on a diverged codebase that vocabulary is usually as inconsistent as the decisions. Capture it, but don't try to _resolve_ it: canonicalising an overloaded term needs the interactive challenge that `/domain-modeling` owns, not a batch guess. As you read, when a term is overloaded, used inconsistently between documents, or contradicts what the code calls the same thing, append a line to `docs/adr/_drafts/TERMS-TO-RESOLVE.md` — the term, and the tension you noticed. That file is a hit-list for a later `/domain-modeling` pass, not a glossary; leave the resolving to that skill.

## Process

1. **Locate the two folders.** Ask the user which folder of design docs to ingest, and confirm where the ADR archive lives (`docs/adr/`, or per `CONTEXT-MAP.md` if the repo has multiple contexts). Create `docs/adr/_drafts/` lazily.

2. **Build or load the ledger.** If `IMPORT-LOG.md` already exists, load it — this is a resumed run; preserve every row's `Status` and `Cleanup` state. When a legacy ledger has no `Cleanup` column, check each row's source path before adding the column: set `Cleanup` to `kept` when the file still exists and `removed` when it does not. If no ledger exists, enumerate the source folder and, before writing any rows, show the user the documents and ask for each document's disposition on completion. This is a per-document selection: the user may keep all, schedule any subset for deletion, or schedule all. Add every document exactly once with `Status` `pending`; set `Cleanup` to `cleanup` for each document selected for deletion and `kept` for each document selected for retention.

   Completion criterion: the ledger lists every source document exactly once, and every row has an explicit cleanup state derived from the existing ledger or the user's choice.

3. **Work the pending documents, one at a time.** For each row still `pending`, in order:

   - **Extract** the decisions the document records — the choices someone made, not the narration around them.
   - **Dedupe.** Check each decision against the drafts already in `docs/adr/_drafts/` and the ADRs already in `docs/adr/`. The same decision restated across several dated docs collapses to **one** draft — add this document to that draft's `Drafts produced` provenance rather than writing a second file.
   - **Cross-reference against the code.** Read the relevant code and decide which of three the decision is:
     - **live** — the code still reflects it → draft it `accepted`.
     - **overtaken** — the code went another way → draft it `superseded`/`deprecated`, and in the ADR note briefly what actually happened, so the record documents the real history rather than a fiction.
     - **obsolete** — the decision and everything it touched are gone → record nothing.
   - **Gate.** Put each surviving decision through the three-part test in `ADR-FORMAT.md`. Drop anything that fails — you want the handful a future reader would genuinely wonder "why?" about, not one ADR per paragraph.
   - **Draft** each keeper as `docs/adr/_drafts/<slug>.md` using the ADR template, with a `Status` frontmatter line when it's anything other than plain `accepted`.
   - **Note any fuzzy vocabulary** the document exposed in `TERMS-TO-RESOLVE.md` (see above) — a byproduct capture, not a blocker.
   - **Mark the row `reviewed`**, recording the slugs it produced.

   Completion criterion: every row in the ledger is `reviewed`. Do not proceed to review while any row is `pending` — that is the resumption point if the session ends here.

4. **Review.** Present a single table — decision · source document(s) · what the code says · proposed status — drawn from the drafts and the ledger. Let the user accept or reject each draft.

5. **Commit the accepted set.** For each accepted draft, assign the next sequential number (scan `docs/adr/` for the highest, increment) and move it to `docs/adr/NNNN-<slug>.md`. Delete rejected drafts, commit the accepted ADRs, and leave the ledger as the record of what was ingested. When `docs/adr/_drafts/` holds nothing but the ledger and any `TERMS-TO-RESOLVE.md`, ADR processing is done.

6. **Retire the scheduled source documents.** After the accepted ADR commit lands, collect exactly the rows whose `Cleanup` state is `cleanup`. If there are none, skip this step. Delete only those source documents and change only their ledger states from `cleanup` to `removed`; rows marked `kept` stay in place and keep that state.

   Do it in two commits, because the log must cite a hash that doesn't exist until the deletion lands:

   - Commit the selected source deletions and their `cleanup` → `removed` ledger transitions together — message `removing legacy docs imported by honist-v:import-adrs`.
   - Write `docs/adr/_drafts/STALE-DOCS-DELETION-LOG.md`: name that deletion commit's short hash and list exactly the paths it deleted, one per line. A future reader can recover an original from the deletion commit's parent with `git show <hash>^:<path>`. Commit the log alone — message `add docs/adr/_drafts/STALE-DOCS-DELETION-LOG.md`.

   Completion criterion: every row selected for cleanup is `removed`, and two commits landed — the selected deletions plus ledger transitions, then the log naming that commit and every path it deleted.

7. **Hand off the vocabulary.** If `TERMS-TO-RESOLVE.md` collected anything, recommend a `/domain-modeling` pass seeded from it — that's where the terms get challenged and written into `CONTEXT.md`. Flag the likely sting: resolving terminology on a diverged codebase will surface code that uses the old or wrong name, and that mismatch list is its own work. A rename is a **wide refactor** — route it through `/to-tickets` (whose wide-refactor exception slices a mechanical rename as expand–contract when it can't land green in one commit) and `/implement`, or, for a pure in-code symbol rename in a typed codebase, just do it atomically and lean on the type-checker. Record the canonical terms now; the code can catch up as its own tickets — don't block the import on renaming anything.
