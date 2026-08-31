---
name: implement
description: 'Implement a piece of work based on a spec or set of tickets.'
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full verification pipeline once at the end.

Once the full verification pipeline passes use /code-review-of-changeset to review the work.

Once /code-review-of-changeset is completed update the ticket's `**Status:**` field to `resolved`.

Finally commit the changes to the current branch.
