# Honist-V

A Claude Code and Codex plugin,

- imported from [Matt Pocock's Skills](https://www.github.com/mattpocock/skills):
  - the engineering and productivity skills
  - modified to use prompt-a-peer[-medium/-high] for reviews in grilling-session, to-spec and to-tickets.
- imported from [Jesse Vincent's Superpowers](https://github.com/obra/superpowers):
  - skills: brainstorming, writing-plans, executing-plans, test-driven-development
  - removed insistance on not working in main
  - added second review by codex
  - skills are user invoked only
- original skills:
  - `prompt-a-peer-medium` / `prompt-a-peer-high`: an agent-dependent skill that lets other skills offload a prompt to a peer agent
- original hooks:
  - a session start hook instruct Claude not to use the AskUserQuestion tool when it will clip its options
  - a `PreToolUse` hook (Claude only) blocks PowerShell here-string syntax (`@'...'@`) in the Bash tool — see below

## Shared skills

The shared skills live in `skills/` and are loaded by both agents. Each variant lives outside `skills/` and is wired per agent in its manifest: Claude auto-discovers `skills/` and the `.claude-plugin` manifest supplements it with `skills-claude/prompt-a-peer`; the `.codex-plugin` manifest lists both `skills/` and `skills-codex/` (Codex loads only the paths its manifest names).

## Agent specific skills

### Prompt a peer medium / high

`prompt-a-peer-medium` and `prompt-a-peer-high` are both skills backed by separate implementations for claude and codex, so any skill using them routes to whatever fits the running agent. On claude, they shell out to codex. On codex, they use a subagent. This lets us divert cost from claude to codex, and is used when we want a fresh context window.

Like the other skills, both set `disable-model-invocation: true` — they are invoked by name, not auto-fired by the model. The plan/spec review flows reach them by naming the skill.

## Bash here-string guard

On Windows, Claude sometimes reaches for PowerShell here-string syntax (`@'...'@`) inside the **Bash** tool, which runs POSIX `sh`. The delimiters aren't valid `sh`, so they leak into the data — most visibly into mangled `git commit` messages. The `PreToolUse` hook at [`plugin/claude-only-hooks/reject-powershell-heredoc.sh`](plugin/claude-only-hooks/reject-powershell-heredoc.sh) blocks such commands before they run, pointing at a POSIX heredoc or the PowerShell tool instead.

**Optional dependency:** the hook uses [`jq`](https://jqlang.github.io/jq/) to read the tool input. If `jq` is not on `PATH`, the hook fails open — it lets the command through rather than blocking every Bash call — so `jq` is recommended but not required.

## Codex

The Codex plugin exposes the same shared skills. The Claude-only hooks (session start and the Bash here-string guard) live in `claude-only-hooks/` and are referenced from the `.claude-plugin` manifest's `hooks` field; the `.codex-plugin` manifest does not list them, so they never load under Codex.

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
