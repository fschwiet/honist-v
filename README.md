# Honist-V

A Claude Code, Codex and Pi plugin/package,

- imported from [Matt Pocock's Skills](https://www.github.com/mattpocock/skills):
  - the engineering and productivity skills
  - modified to use `prompt-a-peer-low`, `prompt-a-peer-medium`, or `prompt-a-peer-high` for reviews in grilling-session, to-spec, and to-tickets.
- imported from [Jesse Vincent's Superpowers](https://github.com/obra/superpowers):
  - skills: brainstorming, writing-plans, executing-plans, test-driven-development
  - removed insistance on not working in main
  - added second review by pi
  - skills are user invoked only
- original skills:
  - `prompt-a-peer-low`, `prompt-a-peer-medium`, and `prompt-a-peer-high`: shared skills that let other skills offload a prompt to a peer agent (via pi)
- original hooks:
  - a session start hook instruct Claude not to use the AskUserQuestion tool when it will clip its options
  - a `PreToolUse` hook (Claude only) blocks PowerShell here-string syntax (`@'...'@`) in the Bash tool — see below

## Shared skills

The shared skills live in `skills/` and are loaded by both agents. Claude auto-discovers `skills/`; the `.codex-plugin` manifest lists both `skills/` and `skills-codex/` (Codex loads only the paths its manifest names). The per-host `skills-codex/` tree contains `sniff-coding-standards`.

## Prompt a peer

`prompt-a-peer-low`, `prompt-a-peer-medium`, and `prompt-a-peer-high` share one implementation across Claude and Codex hosts. Every host shells out to the `pi` CLI using the `openai-codex` provider, with the level selecting `gpt-5.6-luna`, `gpt-5.6-terra`, or `gpt-5.6-sol`, respectively. This diverts peer-review cost away from the host agent and provides a fresh context window.

The skills remain model-invocable so plan, spec, and review flows can reach them by name.

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

The verification pipeline checks formatting, JavaScript and Markdown lint, manifest-reference behavior, and every file or directory referenced by the current plugin and marketplace manifests:

```bash
pnpm install
pnpm verify
```

Other useful scripts:

| Script                            | Description                                   |
| --------------------------------- | --------------------------------------------- |
| `pnpm release`                    | Verify, bump the patch version, and push main |
| `pnpm verify:manifest-references` | Check references in committed manifests       |
| `pnpm test:manifest-references`   | Test manifest-reference verification          |
| `pnpm test:release-version`       | Test the release script's version-bump logic  |
| `pnpm lint`                       | Run ESLint                                    |
| `pnpm lint:md`                    | Lint Markdown with markdownlint               |
| `pnpm format`                     | Format all files with Prettier                |
| `pnpm format:check`               | Check formatting without writing              |

CI runs `pnpm verify` on every push and pull request (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
