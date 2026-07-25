# Honist-V

A Claude Code and Codex plugin,

- imported from [Jesse Vincent's Superpowers](https://github.com/obra/superpowers):
  - skills: brainstorming, writing-plans, executing-plans, test-driven-development
  - removed insistance on working in claude branch, added second review by codex, skills are user invoked only
- a session start hook instruct Claude not to use the AskUserQuestion tool when it will clip its options
- imported from [Matt Pocock's Skills](https://github.com/mattpocock/skills):
  - skills: handoff

## Codex

The Codex plugin exposes the same four skills. The Claude-specific session-start hook remains Claude-only and is not registered by the Codex manifest.

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
