# Honist-V

A Claude Code and Codex plugin,

- imported from [Jesse Vincent's Superpowers](https://github.com/obra/superpowers):
  - skills: brainstorming, writing-plans, executing-plans, test-driven-development
  - removed insistance on working in claude branch, added second review by codex, skills are user invoked only
- a session start hook instruct Claude not to use the AskUserQuestion tool when it will clip its options
- imported from [Matt Pocock's Skills](https://github.com/mattpocock/skills):
  - skills: handoff
- original skills:
  - `prompt-a-peer`: an agent-dependent skill that lets other skills offload a prompt to a peer agent (see below)

## Prompt a peer

`prompt-a-peer` is one skill name backed by two implementations, so any skill that says "prompt a peer" routes to whatever fits the running agent:

- On **Claude** (`skills-claude/prompt-a-peer`) it shells out to the `codex` CLI, moving token cost to a separate agent.
- On **Codex** (`skills-codex/prompt-a-peer`) it spawns a codex subagent, keeping the work off the main context window.

Like the other skills, both set `disable-model-invocation: true` — they are invoked by name, not auto-fired by the model. The plan/spec review flows reach them by naming the skill.

The shared skills live in `skills/` and are loaded by both agents. Each variant lives outside `skills/` and is wired per agent in its manifest: Claude auto-discovers `skills/` and the `.claude-plugin` manifest supplements it with `skills-claude/prompt-a-peer`; the `.codex-plugin` manifest lists both `skills/` and `skills-codex/` (Codex loads only the paths its manifest names).

## Codex

The Codex plugin exposes the same shared skills. The Claude-specific session-start hook remains Claude-only and is not registered by the Codex manifest.

Add this repository as a local marketplace, then install `honist-v`:

```bash
codex plugin marketplace add .
codex plugin add honist-v@honist-v
```

## Verification

The verification pipeline is linting only:

```bash
pnpm install
pnpm verify          # runs format:check + lint + lint:md
```

Other useful scripts:

| Script              | Description                      |
| ------------------- | -------------------------------- |
| `pnpm lint`         | Run ESLint                       |
| `pnpm lint:md`      | Lint Markdown with markdownlint  |
| `pnpm format`       | Format all files with Prettier   |
| `pnpm format:check` | Check formatting without writing |

CI runs `pnpm verify` on every push and pull request (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
