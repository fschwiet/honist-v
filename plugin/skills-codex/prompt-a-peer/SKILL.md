---
name: prompt-a-peer
description: Prompt your peer — spawn a codex subagent to run a task or review in a fresh context, keeping the work off your main context window. Use when a skill needs a second-agent pass (plan, spec, or code review), or the user asks to hand a task to a peer.
---

# Prompt a peer

Your **peer** is a fresh codex subagent that runs the task in its own context. Delegating to it keeps the work off your main context window and gives an independent pass.

Spawn a subagent with the prompt. Present the prompt as work authored by someone else, so the peer reviews it without deference.

- For a code, plan, or spec review, dispatch the `$review-agent` skill — it is built for this and returns severity-ranked findings.
- For any other task, spawn a general subagent with the prompt.
- Give the peer a generous budget — it runs a full agent loop.

## After the peer returns

Relay the actionable content — findings, answers, decisions — to the user. Do not replay the whole subagent transcript. For review feedback, follow the calling skill's own rules for folding in fixes and surfacing what was discarded.
