---
name: implement
description: 'Implement a piece of work based on a spec or set of tickets.'
disable-model-invocation: true
---

Remember the starting commit so it can be passed as the starting point of a later review.

Orchestrate the implementation of the tickets given by the user. Have an agent implement the next unblocked ticket one at a time until all tickets are implemented.

The agent should use /tdd where possible and check their work with stages of the verification pipeline relevant to their work (including at least formatting, linting and testing as outlined in the project's context).

Once all tickets have been resolved run the full verification pipeline and address any issues it raises.

When the full verification pipeline passes use /code-review-of-changeset to review the work, indicating the starting commit and the tickets that were implemented.

Repeat the full verification pipeline once issues indicated by /code-review-of-changeset are addressed.

When the /code-review-of-changeset issues are addressed and the full verification pipeline passes update the ticket's `**Status:**` field to `resolved` and commit the changes to the current branch.
