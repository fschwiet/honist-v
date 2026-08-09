#!/usr/bin/env bash
# Unit tests for assertions.sh.
#
# These run against a recorded Claude transcript and its corresponding pi
# session so the success-detection logic can be validated instantly, offline,
# and for free -- unlike test.sh, which drives live, paid agent loops.
#
# Run: bash tests/prompt-a-peer/assertions.test.sh   (or ./tests/run.ps1 from pwsh)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/assertions.sh"

# Work against a copy in a temp dir, mirroring how test.sh reads transcripts
# from .test-run and keeping the checked-in fixture pristine.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TRANSCRIPT="$TMP_DIR/claude-medium.jsonl"
cp "$SCRIPT_DIR/fixtures/claude-medium.jsonl" "$TRANSCRIPT"
PI_SESSION="$TMP_DIR/pi-session.jsonl"
cp "$SCRIPT_DIR/fixtures/claude-medium-pi-session.jsonl" "$PI_SESSION"
WRONG_MODEL_SESSION="$TMP_DIR/wrong-model-pi-session.jsonl"
sed 's/"modelId":"gpt-5.6-terra"/"modelId":"gpt-5.6-sol"/' \
  "$PI_SESSION" > "$WRONG_MODEL_SESSION"
ROUND_TRIP_MARKER="PROMPT_A_PEER_ROUND_TRIP_OK"
CODEX_HOST_TRANSCRIPT="$TMP_DIR/codex-host.jsonl"
printf '%s\n' \
  'Warning: a host diagnostic may precede the JSONL stream' \
  '{"type":"item.completed","item":{"type":"agent_message","text":"PROMPT_A_PEER_ROUND_TRIP_OK"}}' \
  > "$CODEX_HOST_TRANSCRIPT"
MISSING_MARKER_TRANSCRIPT="$TMP_DIR/missing-marker.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":[{"type":"text","text":"Prompt includes PROMPT_A_PEER_ROUND_TRIP_OK"}]}}' \
  '{"type":"result","subtype":"success","result":"Peer call was skipped"}' \
  > "$MISSING_MARKER_TRANSCRIPT"

# Pin the expected root to what is baked into the fixture data so this unit
# test stays independent of where the repo happens to be checked out now.
FIXTURE_REPO_ROOT="C:/code/honist-v"
SKILL_RELPATH="plugin/skills/prompt-a-peer-medium"
EXPECTED_MODEL="gpt-5.6-terra"

PASS=0
FAIL=0

check_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ok   $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $name: expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

# Runs a command (should not print to stdout) and checks its exit code.
check_rc() {
  local name="$1" expected_rc="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq "$expected_rc" ]; then
    echo "  ok   $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $name: expected rc=$expected_rc, got rc=$rc"
    FAIL=$((FAIL + 1))
  fi
}

echo "normalize_path:"
check_eq "windows drive path"  "/c/code/honist-v" "$(normalize_path 'C:\code\honist-v')"
check_eq "git bash path"       "/c/code/honist-v" "$(normalize_path '/c/code/honist-v')"
check_eq "wsl mount path"      "/c/code/honist-v" "$(normalize_path '/mnt/c/code/honist-v')"

echo "extractors:"
check_eq "low skill uses medium thinking" "medium" \
  "$(grep -Eo -- '--thinking [a-z]+' "$SCRIPT_DIR/../../plugin/skills/prompt-a-peer-low/SKILL.md" | head -n 1 | cut -d ' ' -f 2)"
check_eq "skill base dir" \
  'C:\code\honist-v\plugin\skills\prompt-a-peer-medium' \
  "$(extract_skill_base_dir "$TRANSCRIPT")"
check_eq "pi session model" "$EXPECTED_MODEL" "$(extract_pi_session_model "$PI_SESSION")"
check_eq "claude final output" "$ROUND_TRIP_MARKER" \
  "$(extract_host_final_output "$TRANSCRIPT" claude)"
check_eq "codex final output" "$ROUND_TRIP_MARKER" \
  "$(extract_host_final_output "$CODEX_HOST_TRANSCRIPT" codex)"

echo "verify_claude_success:"
check_rc "passes on a good run" 0 \
  verify_claude_success "$TRANSCRIPT" "$FIXTURE_REPO_ROOT" "$SKILL_RELPATH" \
    "$EXPECTED_MODEL" "$PI_SESSION" "$ROUND_TRIP_MARKER"
check_rc "fails on wrong expected model" 1 \
  verify_claude_success "$TRANSCRIPT" "$FIXTURE_REPO_ROOT" "$SKILL_RELPATH" \
    "gpt-5.6-sol" "$PI_SESSION" "$ROUND_TRIP_MARKER"
check_rc "fails when skill loaded from a different root" 1 \
  verify_claude_success "$TRANSCRIPT" "/some/other/checkout" "$SKILL_RELPATH" \
    "$EXPECTED_MODEL" "$PI_SESSION" "$ROUND_TRIP_MARKER"

# A transcript with neither evidence event must fail (not spuriously pass).
EMPTY="$TMP_DIR/empty.jsonl"
: > "$EMPTY"
check_rc "fails on an empty transcript" 1 \
  verify_claude_success "$EMPTY" "$FIXTURE_REPO_ROOT" "$SKILL_RELPATH" \
    "$EXPECTED_MODEL" "$PI_SESSION" "$ROUND_TRIP_MARKER"

echo "verify_success:"
check_rc "passes for a claude host" 0 \
  verify_success "$PI_SESSION" "$TRANSCRIPT" claude "$EXPECTED_MODEL" "$ROUND_TRIP_MARKER"
check_rc "passes for a codex host" 0 \
  verify_success "$PI_SESSION" "$CODEX_HOST_TRANSCRIPT" codex "$EXPECTED_MODEL" "$ROUND_TRIP_MARKER"
check_rc "fails on the wrong pi model" 1 \
  verify_success "$WRONG_MODEL_SESSION" "$TRANSCRIPT" claude "$EXPECTED_MODEL" "$ROUND_TRIP_MARKER"
check_rc "fails when only the prompt contains the marker" 1 \
  verify_success "$PI_SESSION" "$MISSING_MARKER_TRANSCRIPT" claude "$EXPECTED_MODEL" "$ROUND_TRIP_MARKER"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
