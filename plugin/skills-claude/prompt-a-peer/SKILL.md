---
name: prompt-a-peer
description: Prompt your peer agent — shell out to the codex CLI to run a prompt in a separate agent, offloading token cost from this session. Use when a skill wants to delegate a prompt to a second agent, or the user asks to hand a task to codex or a peer.
---

# Prompt a peer

Your **peer** is a separate agent — here, codex — that runs the prompt in its own context. Delegating to it moves token cost out of this session and gives an independent pass. Reach the peer by shelling out to the `codex` CLI with the Bash tool.

## The command

Write the prompt to a temp file (OS temp dir, not the workspace), then:

```bash
codex exec --sandbox read-only "$(cat <promptfile>)" --output-last-message <resultfile> < /dev/null
```

- **`< /dev/null` is mandatory.** Without it codex blocks on stdin and the call hangs until timeout. Append it to every invocation.
- Passing the prompt through `"$(cat <promptfile>)"` keeps multi-line text and quoting intact.
- `--output-last-message <resultfile>` writes only the peer's final message; read that file to get the response.
- Set a generous timeout — the peer runs a full agent loop; several minutes is typical.

## Sandbox

- `--sandbox read-only` when the peer only needs to read. This is the default.
- `--sandbox workspace-write` when the peer must edit files.

## Returning the response

The peer's final message (in the result file) is the response. The skill that invoked prompt-a-peer decides how to use it.
