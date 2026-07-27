---
name: prompt-a-peer
description: Prompt your peer agent — shell out to the codex CLI to run a task or review in a separate agent, offloading token cost from this session. Use when a skill needs a second-agent pass (plan, spec, or code review), or the user asks to hand a task to codex or a peer.
---

# Prompt a peer

Your **peer** is a separate agent — here, codex — that runs the task in its own context. Delegating to it moves token cost out of this session and gives an independent pass. Reach the peer by shelling out to the `codex` CLI with the Bash tool.

## The command

Write the prompt to a temp file (OS temp dir, not the workspace), then:

```bash
codex exec --sandbox read-only "$(cat <promptfile>)" --output-last-message <resultfile> < /dev/null
```

- **`< /dev/null` is mandatory.** Without it codex blocks on stdin and the call hangs until timeout. Append it to every invocation.
- Passing the prompt through `"$(cat <promptfile>)"` keeps multi-line text and quoting intact.
- `--output-last-message <resultfile>` writes only the peer's final message; read that file for the result instead of parsing the transcript.
- Set a generous timeout — the peer runs a full agent loop. 10 minutes (600000 ms) suits a review.

## Sandbox

- `--sandbox read-only` for reviews and any read-only task (Standards, Spec, or code review). This is the default.
- `--sandbox workspace-write` only when the peer must edit files.

## After the peer returns

Read the result file and relay its actionable content — findings, answers, decisions. Do not replay the raw transcript. For review feedback, follow the calling skill's own rules for folding in fixes and surfacing what was discarded.
