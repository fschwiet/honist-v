---
name: prompt-a-peer-low
description: Prompts a peer agent with a lightweight model.
---

Your **peer** is a separate pi agent. Reach the peer by shelling out to the `pi` CLI with the Bash tool.

## The command

Write the prompt to a temp file (OS temp dir, not the workspace), then:

```bash
pi --provider "openai-codex" --model "gpt-5.6-luna" --thinking medium -p "@$promptfile" < /dev/null > "$resultfile"
```

- **`< /dev/null` is mandatory.** While stdin stays open pi waits on it and the call hangs until timeout. Append it to every invocation.
- `"@$promptfile"` hands pi the file itself, so multi-line text, quoting, and prompts past the command-line length limit all survive; the quotes keep OS temp dirs with spaces working.
- pi prints the peer's final message on stdout, so `> "$resultfile"` captures the reply whole; read that file to get the response.
- Extend the shell tool's timeout to ten minutes.
