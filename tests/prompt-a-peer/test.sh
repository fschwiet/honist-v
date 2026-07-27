#!/usr/bin/env bash
# Manual, on-demand test of the prompt-a-peer-medium / prompt-a-peer-high skills.
# Each test asks a host agent (claude or codex) to use one of the skills to ask
# its peer what model it is running as, then checks the peer's reported model.
#
# claude tests invoke the skill by name via --plugin-dir, which loads the
# plugin from this repo's checkout for that session only -- this exercises
# the real skill-discovery/invocation path other skills use in production.
#
# codex has no equivalent per-invocation plugin-loading flag; the only working
# mechanism found is a persistent, global `codex plugin add`, which we want to
# avoid. So codex tests instead tell the agent to read the skill's SKILL.md by
# repo-relative path and follow its instructions directly -- this limits scope
# to "does following this file's instructions produce correct behavior"
# rather than "is the skill correctly discovered and routed to", but it
# requires no persistent config changes and always exercises the SKILL.md
# actually checked out in this repo.
#
# Not wired into pnpm verify / CI: each test runs a real, paid, multi-minute
# agent loop against live claude/codex CLIs.
#
# Flags restrict which tests run: --medium --high --claude --codex.
# One flag narrows to two tests, two flags (one level + one agent) narrow to
# one test. No validation is done on the flag combination passed in.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/assertions.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugin"
SCHEMA_FILE="$SCRIPT_DIR/schema.json"
RUN_DIR="$SCRIPT_DIR/.test-run"
mkdir -p "$RUN_DIR"
cd "$REPO_ROOT"

FILTER_LEVELS=()
FILTER_AGENTS=()
for arg in "$@"; do
  case "$arg" in
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
  echo "Use the ${skill} skill to ask your peer what model it is running as. Reply with nothing but JSON matching the schema, using the exact model identifier the peer reported."
}

prompt_for_skill_file() {
  local skill_path="$1"
  echo "Read ${skill_path} in this repository and follow its instructions to ask your peer what model it is running as. Reply with nothing but JSON matching the schema, using the exact model identifier the peer reported."
}

report_result() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS $name"
  else
    echo "FAIL $name: expected '$expected', got '$actual' (see .test-run/${name}.jsonl)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Codex's --json output is a JSONL event stream; the peer's reply is the last
# item.completed event whose item.type is agent_message.
extract_codex_model() {
  local transcript="$1"
  local last_msg
  last_msg=$(grep '"type":"item.completed"' "$transcript" | grep '"type":"agent_message"' | tail -n 1 | jq -r '.item.text // empty' 2>/dev/null)
  [ -z "$last_msg" ] && return
  echo "$last_msg" | jq -r '.model // empty' 2>/dev/null
}

run_claude_test() {
  local name="$1" skill="$2" expected="$3"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo "Running $name..."
  local transcript="$RUN_DIR/${name}.jsonl"
  local prompt
  prompt="$(prompt_for_skill_name "$skill")"

  claude -p "$prompt" \
    --allowedTools "" \
    --effort low \
    --model haiku \
    --output-format stream-json --verbose \
    --plugin-dir "$PLUGIN_DIR" \
    --permission-mode bypassPermissions \
    --json-schema "$(cat "$SCHEMA_FILE")" \
    > "$transcript" 2>&1

  # Verify from intermediate transcript evidence (skill base dir + codex banner
  # model), not the peer's final answer -- the peer routinely misreports its own
  # model. See assertions.sh for the rationale.
  if verify_claude_success "$transcript" "$REPO_ROOT" "plugin/skills-claude/$skill" "$expected"; then
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
  local prompt
  prompt="$(prompt_for_skill_file "$skill_path")"

  codex exec --json --output-schema "$SCHEMA_FILE" --sandbox workspace-write "$prompt" \
    < /dev/null > "$transcript" 2>&1

  report_result "$name" "$expected" "$(extract_codex_model "$transcript")"
}

if level_allowed medium && agent_allowed claude; then
  run_claude_test "claude-medium" "prompt-a-peer-medium" "gpt-5.6-terra"
fi

if level_allowed high && agent_allowed claude; then
  run_claude_test "claude-high" "prompt-a-peer-high" "gpt-5.6-sol"
fi

if level_allowed medium && agent_allowed codex; then
  run_codex_test "codex-medium" "plugin/skills-codex/prompt-a-peer-medium/SKILL.md" "gpt-5.6-terra"
fi

if level_allowed high && agent_allowed codex; then
  run_codex_test "codex-high" "plugin/skills-codex/prompt-a-peer-high/SKILL.md" "gpt-5.6-sol"
fi

echo "$((TOTAL_COUNT - FAIL_COUNT))/$TOTAL_COUNT passed"
[ "$FAIL_COUNT" -eq 0 ]
