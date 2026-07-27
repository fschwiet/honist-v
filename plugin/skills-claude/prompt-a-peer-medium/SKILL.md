---
name: prompt-a-peer-medium
description: Prompts a peer agent with a balanced model.
---

Your **peer** is a separate codex agent. Reach the peer by shelling out to the `codex` CLI with the Bash tool.

## The command

Write the prompt to a temp file (OS temp dir, not the workspace), then:

```bash
codex exec --model "gpt-5.6-terra" --sandbox workspace-write "$(cat "$promptfile")" --output-last-message "$resultfile" < /dev/null
```

- **`< /dev/null` is mandatory.** Without it codex blocks on stdin and the call hangs until timeout. Append it to every invocation.
- Passing the prompt through `"$(cat "$promptfile")"` keeps multi-line text and quoting intact; quote the paths so OS temp dirs with spaces still work.
- `--output-last-message "$resultfile"` writes only the peer's final message; read that file to get the response.
- Set a generous timeout — the peer runs a full agent loop; allow up to 10 minutes (600000 ms).
