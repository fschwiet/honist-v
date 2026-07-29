# GitHub Issue Category Prefix and Label Design

## Problem Statement

`to-spec` (`plugin/skills/mattpocock-skills/engineering/to-spec/SKILL.md`) and
`to-tickets` (`plugin/skills/mattpocock-skills/engineering/to-tickets/SKILL.md`)
both publish issues to GitHub via the shared convention doc
(`plugin/skills/mattpocock-skills/engineering/setup-matt-pocock-skills/issue-tracker-github.md`),
but neither the skills nor the shared doc give issues a visual or
machine-filterable marker of which skill produced them. In an issue list
that mixes specs, tickets, and anything else the repo tracks, there's no way
to tell at a glance — or via `gh issue list --label` — which issues are
specs and which are tickets.

## Solution

Add a category convention to the shared GitHub tracker doc: an issue's title
is prefixed with its category in caps (`SPEC:`, `TICKET:`), and the issue is
tagged with the same category in lowercase (`spec`, `ticket`), applied
alongside whatever labels the publishing skill already applies (e.g.
`ready-for-agent`). `to-spec` and `to-tickets` each reference the convention
with their own category when publishing to GitHub.

This is scoped to GitHub only — GitLab and local-file tracking are
unaffected — and to `to-spec`/`to-tickets` only. `wayfinder`'s map/child
issues already have their own label scheme (`wayfinder:map`,
`wayfinder:<type>`) and are left untouched.

## Implementation Decisions

### New shared section in `issue-tracker-github.md`

Add a `## Category prefix and label` section:

- When a skill publishing to GitHub has a category (`SPEC` for `to-spec`,
  `TICKET` for `to-tickets`), prefix the issue title with `<CATEGORY>: ` and
  add the lowercase label (`spec`, `ticket`) alongside any other labels the
  skill applies (e.g. `ready-for-agent`).
- The label is assumed to already exist on the repo, the same as
  `ready-for-agent` and the other triage labels — no skill in this plugin
  automates label creation today, so this doesn't introduce new behavior
  there. If the label doesn't exist, issue creation fails and the user
  creates it manually.

### `to-spec/SKILL.md` step 5 changes

The step ("Publish the reviewed spec to the project issue tracker...") gets
a note: when the tracker is GitHub, apply the `SPEC:` title prefix and
`spec` label per the shared convention, in addition to `ready-for-agent`.

### `to-tickets/SKILL.md` step 6 changes

The "A real issue tracker (GitHub, Linear, …)" bullet gets a note scoped to
GitHub: apply the `TICKET:` title prefix and `ticket` label per the shared
convention, in addition to `ready-for-agent`.

## Testing Decisions

This is a documentation-only change to skill instructions (Markdown
prompts), not executable code — there is no automated test surface. Manual
verification: run `to-spec` and `to-tickets` against a scratch GitHub repo
with `spec` and `ticket` labels pre-created, confirm published issue titles
carry the correct `SPEC:`/`TICKET:` prefix and the correct lowercase label
is applied alongside `ready-for-agent`.

## Out of Scope

- Auto-creating the `spec`/`ticket` labels if missing.
- GitLab (`issue-tracker-gitlab.md`) and local-file tracker
  (`issue-tracker-local.md`) conventions.
- `wayfinder`'s map/child issue labeling scheme.
- Retroactively renaming or relabeling existing issues.

## Further Notes

None.
