#!/usr/bin/env bash
# Manual, on-demand test of the three prompt-a-peer skills. Each test asks a
# host agent (claude or codex) to use one of the shared skills, then checks pi's
# session record for the selected model and the host output for a round-trip
# marker returned by the peer.
#
# claude tests invoke the skill by name via --plugin-dir, which loads the
# plugin from this repo's checkout for that session only -- this exercises
# the real skill-discovery/invocation path other skills use in production.
#
# Codex has no equivalent per-invocation plugin-loading flag; the only working
# mechanism found is a persistent, global `codex plugin add`, which we want to
# avoid. So codex tests instead tell the agent to read the skill's SKILL.md by
# repo-relative path and follow its instructions directly. Both hosts exercise
# the same file; only how they reach it differs. The Codex path limits scope to
# "does following this file's instructions produce correct behavior" rather
# than "is the skill correctly discovered and routed to", but it requires no
# persistent config changes.
#
# Not wired into pnpm verify / CI: each test runs a real, paid, multi-minute
# agent loop against live claude/codex CLIs.
#
# Flags restrict which tests run: --low --medium --high --claude --codex.
# One flag narrows to two tests, two flags (one level + one agent) narrow to
# one test. No validation is done on the flag combination passed in.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/assertions.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugin"
RUN_DIR="$SCRIPT_DIR/.test-run"
ROUND_TRIP_MARKER="PROMPT_A_PEER_ROUND_TRIP_OK"
mkdir -p "$RUN_DIR"
cd "$REPO_ROOT"

FILTER_LEVELS=()
FILTER_AGENTS=()
for arg in "$@"; do
  case "$arg" in
    --low) FILTER_LEVELS+=("low") ;;
    --medium) FILTER_LEVELS+=("medium") ;;
    --high) FILTER_LEVELS+=("high") ;;
    --claude) FILTER_AGENTS+=("claude") ;;
    --codex) FILTER_AGENTS+=("codex") ;;
  esac
done

level_allowed() {
  local level="$1"
  [ ${#FILTER_LEVELS[@]} -eq 0 ] && return 0
  local f
  for f in "${FILTER_LEVELS[@]}"; do
    [ "$f" = "$level" ] && return 0
  done
  return 1
}

agent_allowed() {
  local agent="$1"
  [ ${#FILTER_AGENTS[@]} -eq 0 ] && return 0
  local f
  for f in "${FILTER_AGENTS[@]}"; do
    [ "$f" = "$agent" ] && return 0
  done
  return 1
}

TOTAL_COUNT=0
FAIL_COUNT=0

prompt_for_skill_name() {
  local skill="$1"
  echo "Use the ${skill} skill to ask your peer to respond with exactly '${ROUND_TRIP_MARKER}'. Reply with the peer's response and nothing else."
}

prompt_for_skill_file() {
  local skill_path="$1"
  echo "Read ${skill_path} in this repository and follow its instructions to ask your peer to respond with exactly '${ROUND_TRIP_MARKER}'. Reply with the peer's response and nothing else."
}

new_pi_session_dir() {
  local name="$1"
  mktemp -d "$RUN_DIR/${name}-pi-session.XXXXXX"
}

find_pi_session() {
  local session_dir="$1"
  find "$session_dir" -type f -name '*.jsonl' -print 2>/dev/null | head -n 1
}

run_claude_test() {
  local name="$1" skill="$2" expected="$3"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo "Running $name..."
  local transcript="$RUN_DIR/${name}.jsonl"
  local session_dir session
  session_dir="$(new_pi_session_dir "$name")"
  local prompt
  prompt="$(prompt_for_skill_name "$skill")"

  PI_CODING_AGENT_SESSION_DIR="$session_dir" claude -p "$prompt" \
    --allowedTools "" \
    --effort low \
    --model haiku \
    --output-format stream-json --verbose \
    --plugin-dir "$PLUGIN_DIR" \
    --permission-mode bypassPermissions \
    > "$transcript" 2>&1

  session="$(find_pi_session "$session_dir")"
  [ -n "$session" ] || session=/dev/null
  if verify_claude_success "$transcript" "$REPO_ROOT" "plugin/skills/$skill" \
    "$expected" "$session" "$ROUND_TRIP_MARKER"; then
    echo "PASS $name"
  else
    echo "FAIL $name (see .test-run/${name}.jsonl)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_codex_test() {
  local name="$1" skill_path="$2" expected="$3"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo "Running $name..."
  local transcript="$RUN_DIR/${name}.jsonl"
  local session_dir session
  session_dir="$(new_pi_session_dir "$name")"
  local prompt
  prompt="$(prompt_for_skill_file "$skill_path")"

  # --approve-for-me keeps Codex in workspace-write while allowing the
  # non-interactive harness to approve launching the external pi executable.
  PI_CODING_AGENT_SESSION_DIR="$session_dir" codex \
    --model gpt-5.6-luna \
    exec \
    --skip-git-repo-check \
    --ignore-user-config \
    --approve-for-me \
    --json \
    "$prompt" \
    < /dev/null > "$transcript" 2>&1

  session="$(find_pi_session "$session_dir")"
  [ -n "$session" ] || session=/dev/null
  if verify_success "$session" "$transcript" codex "$expected" "$ROUND_TRIP_MARKER"; then
    echo "PASS $name"
  else
    echo "FAIL $name (see .test-run/${name}.jsonl)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

if level_allowed low && agent_allowed claude; then
  run_claude_test "claude-low" "prompt-a-peer-low" "gpt-5.6-luna"
fi

if level_allowed medium && agent_allowed claude; then
  run_claude_test "claude-medium" "prompt-a-peer-medium" "gpt-5.6-terra"
fi

if level_allowed high && agent_allowed claude; then
  run_claude_test "claude-high" "prompt-a-peer-high" "gpt-5.6-sol"
fi

if level_allowed low && agent_allowed codex; then
  run_codex_test "codex-low" "plugin/skills/prompt-a-peer-low/SKILL.md" "gpt-5.6-luna"
fi

if level_allowed medium && agent_allowed codex; then
  run_codex_test "codex-medium" "plugin/skills/prompt-a-peer-medium/SKILL.md" "gpt-5.6-terra"
fi

if level_allowed high && agent_allowed codex; then
  run_codex_test "codex-high" "plugin/skills/prompt-a-peer-high/SKILL.md" "gpt-5.6-sol"
fi

echo "$((TOTAL_COUNT - FAIL_COUNT))/$TOTAL_COUNT passed"
[ "$FAIL_COUNT" -eq 0 ]
