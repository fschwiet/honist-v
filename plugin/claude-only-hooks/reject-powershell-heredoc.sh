#!/usr/bin/env bash
#
# PreToolUse guard for the Bash tool. Claude only: it is registered via the
# plugin's claude-only-hooks/hooks.json, referenced from the .claude-plugin
# manifest but not the .codex-plugin manifest.
#
# On Windows, Claude sometimes reaches for PowerShell here-string syntax
# (@'...'@ or @"..."@) inside the *Bash* tool, which runs POSIX sh. The @ and
# delimiters aren't valid sh, so they leak into the data — most visibly into
# git commit messages. This blocks the call *before* it runs, with a corrective
# message, turning a mangled-commit-plus-cleanup round trip into an immediate
# self-correct. See issue #2.
#
# A real PowerShell here-string always spans lines: the opener ends a line with
# @' / @", and the closer begins a line with '@ / "@. Matching those two shapes
# gives full recall on the actual mistake with almost no false positives (a
# mid-line @' in, say, a sed script won't trip it).
set -euo pipefail

# jq is an optional dependency. If it's not installed, fail open: let the
# command through rather than blocking every Bash call. See README.md.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

command=$(jq -r '.tool_input.command // ""')

if printf '%s' "$command" | grep -qE "@['\"][[:space:]]*$|^[[:space:]]*['\"]@"; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"This Bash command uses PowerShell here-string syntax (@'...'@ or @\"...\"@). The Bash tool runs POSIX sh, where those delimiters are not valid and leak into the data (e.g. a mangled commit message). Fix: use a POSIX heredoc, e.g. `git commit -F - <<'EOF'` ... `EOF`, or run this through the PowerShell tool, which supports here-strings natively."}}
JSON
fi
