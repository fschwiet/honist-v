---
name: prompt-a-peer
description: Prompt your peer — spawn a codex subagent to run a prompt in a fresh context, keeping the work off your main context window. Use when a skill wants to delegate a prompt to a second agent, or the user asks to hand a task to a peer.
---

# Prompt a peer

Your **peer** is a fresh codex subagent that runs the prompt in its own context. Delegating to it keeps the work off your main context window and gives an independent pass.

Spawn a subagent with the prompt. Present the prompt as work authored by someone else, so the peer responds without deference. Give it a generous budget — it runs a full agent loop.

When the prompt is a self-contained code, plan, or spec review, the built-in `$review-agent` skill is a ready-made peer that returns severity-ranked findings; otherwise spawn a general subagent.

## Returning the response

The subagent's response is the result. The skill that invoked prompt-a-peer decides how to use it.
