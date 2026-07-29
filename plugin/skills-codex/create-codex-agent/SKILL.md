---
name: create-codex-agent
description: Create or update a project-scoped Codex custom-agent TOML definition. Use when the user asks for a named Codex agent, its model or reasoning settings, sandbox, or developer instructions.
disable-model-invocation: true
---

# Create a Codex Agent

Create one project-scoped agent definition at `.codex/agents/<name>.toml`.

## Process

1. Capture the requested agent name, purpose, input, model, reasoning effort, sandbox needs, and required output. Ask only for information that is necessary and not supplied.

2. Consult OpenAI's Codex documentation for the TOML schema: [Subagents — Custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents.md#custom-agents). Use the documentation to confirm the required fields (`name`, `description`, and `developer_instructions`) and supported configuration keys. Do not scan the repository for other agent definitions or imitate their style.

3. Write `.codex/agents/<name>.toml` with the supplied values. Use `name` as the agent's invocation name, `description` as concise guidance for when to use it, and `developer_instructions` to define its narrow job, inputs, scope, and exact output structure. Set `model` and `model_reasoning_effort` when the user specifies them. Set `sandbox_mode = "read-only"` for an analysis-only agent unless the task needs writes.

4. Read back the resulting file and run `git diff --check`. Report the created path and any assumptions made.

## TOML shape

```toml
name = "<agent-name>"
description = "<when this agent should be used>"
model = "<model>"
model_reasoning_effort = "<low|medium|high|xhigh|max|ultra>"
sandbox_mode = "<read-only|workspace-write>"
developer_instructions = """
<focused instructions, including input and exact output format>
"""
```
