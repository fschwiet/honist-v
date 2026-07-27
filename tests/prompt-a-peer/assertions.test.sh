#!/usr/bin/env bash
# Unit tests for assertions.sh.
#
# These run against a recorded transcript fixture (fixtures/claude-medium.jsonl)
# so the success-detection logic can be validated instantly, offline, and for
# free -- unlike test.sh, which drives live, paid claude/codex agent loops.
#
# The fixture is a real "--claude --medium" run in which the peer *misreported*
# its own model ("gpt-5.6-sol") even though the codex CLI banner shows the
# correct one ("gpt-5.6-terra"). That is exactly the case that fooled the old
# final-answer check, so it is the case these assertions must get right.
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

# The fixture was recorded with this repo checked out at C:\code\honist-v, so
# pin the expected root to what is baked into the fixture -- keeps this unit
# test independent of where the repo happens to be checked out now.
FIXTURE_REPO_ROOT="C:/code/honist-v"
SKILL_RELPATH="plugin/skills-claude/prompt-a-peer-medium"
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
check_eq "skill base dir" \
  'C:\code\honist-v\plugin\skills-claude\prompt-a-peer-medium' \
  "$(extract_skill_base_dir "$TRANSCRIPT")"
check_eq "codex banner model" "$EXPECTED_MODEL" "$(extract_codex_banner_model "$TRANSCRIPT")"

# Sanity: this is the value the old check trusted, and it is the WRONG model --
# proving the final answer is unreliable and must not be what we assert on.
check_eq "peer's (unreliable) final answer" \
  "gpt-5.6-sol" \
  "$(tail -n 1 "$TRANSCRIPT" | jq -r '.structured_output.model // empty')"

echo "verify_claude_success:"
check_rc "passes on a good run" 0 \
  verify_claude_success "$TRANSCRIPT" "$FIXTURE_REPO_ROOT" "$SKILL_RELPATH" "$EXPECTED_MODEL"
check_rc "fails on wrong expected model" 1 \
  verify_claude_success "$TRANSCRIPT" "$FIXTURE_REPO_ROOT" "$SKILL_RELPATH" "gpt-5.6-sol"
check_rc "fails when skill loaded from a different root" 1 \
  verify_claude_success "$TRANSCRIPT" "/some/other/checkout" "$SKILL_RELPATH" "$EXPECTED_MODEL"

# A transcript with neither evidence event must fail (not spuriously pass).
EMPTY="$TMP_DIR/empty.jsonl"
: > "$EMPTY"
check_rc "fails on an empty transcript" 1 \
  verify_claude_success "$EMPTY" "$FIXTURE_REPO_ROOT" "$SKILL_RELPATH" "$EXPECTED_MODEL"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
