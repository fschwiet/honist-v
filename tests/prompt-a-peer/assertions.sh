#!/usr/bin/env bash
# Success-detection helpers for the prompt-a-peer tests, factored out of
# test.sh so they can be unit-tested against recorded fixtures
# (see assertions.test.sh) without spending a live, paid agent run.
#
# Why not just trust the peer's final answer? The peer (a codex agent) is asked
# what model it runs as, but models frequently *misreport their own identity*
# in natural language -- in the recorded fixture the peer answers "gpt-5.6-sol"
# while actually running gpt-5.6-terra. Two pieces of CLI-written evidence and
# one liveness check are reliable instead:
#
#   1. Skill discovery: on invoking the skill, the claude host receives a
#      user-role text event beginning "Base directory for this skill: <path>".
#      <path> is the on-disk location the skill loaded from; if it points inside
#      this repo checkout, the skill loaded from the repo (not a global install).
#
#   2. Model actually used: the harness gives each host run an isolated pi
#      session directory. pi writes a `model_change` JSONL record from its own
#      config, so it is trustworthy and independent of the peer's claims.
#
#   3. Completed round trip: the peer is asked for a fixed marker, and the
#      marker must appear in the host's final output (not merely in its prompt).

# Normalize a filesystem path for cross-form comparison: lowercase, backslashes
# to forward slashes, and Windows drive (C:\) / WSL mount (/mnt/c) prefixes to a
# common /<drive>/ form. Lets a Git Bash path (/c/code/...) compare equal to the
# Windows path a claude CLI records in its transcript (C:\code\...).
normalize_path() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr '\\' '/' \
    | sed -E -e 's#^([a-z]):/#/\1/#' -e 's#^/mnt/([a-z])/#/\1/#'
}

# Emit the directory the skill loaded from, per the first
# "Base directory for this skill:" user text event in the transcript.
# Emits nothing if no such event is present.
extract_skill_base_dir() {
  local transcript="$1"
  grep -F 'Base directory for this skill:' "$transcript" \
    | jq -r '.message.content[]? | select(.type=="text") | .text' 2>/dev/null \
    | grep -F 'Base directory for this skill:' \
    | head -n 1 \
    | sed -E 's/^Base directory for this skill:[[:space:]]*//'
}

# Emit the model id selected by pi, as recorded in its session JSONL by the
# CLI. Emits nothing if no openai-codex model-change event is present.
extract_pi_session_model() {
  local session="$1"
  jq -r 'select(.type == "model_change" and .provider == "openai-codex")
         | .modelId' "$session" 2>/dev/null \
    | head -n 1
}

# Emit the host agent's final output without matching marker text echoed in the
# original prompt or in intermediate tool events.
extract_host_final_output() {
  local transcript="$1" host="$2"
  case "$host" in
    claude)
      grep -F '"type":"result"' "$transcript" \
        | jq -r 'select(.type == "result" and .subtype == "success")
                 | .result // empty' 2>/dev/null \
        | tail -n 1
      ;;
    codex)
      grep -F '"type":"item.completed"' "$transcript" \
        | jq -r 'select(.type == "item.completed"
                        and .item.type == "agent_message")
                 | .item.text // empty' 2>/dev/null \
        | tail -n 1
      ;;
  esac
}

# Verify that pi's own session record names the expected model and that the
# host's final output contains the round-trip marker returned by the peer.
# Args: <pi_session> <host_transcript> <host> <expected_model> <marker>
verify_success() {
  local session="$1" transcript="$2" host="$3" expected_model="$4" marker="$5"
  local ok=0

  local session_model
  session_model="$(extract_pi_session_model "$session")"
  if [ -z "$session_model" ]; then
    echo "  peer model: MISSING (no openai-codex model_change in pi session)" >&2
    ok=1
  elif [ "$session_model" != "$expected_model" ]; then
    echo "  peer model: expected '$expected_model', pi session shows '$session_model'" >&2
    ok=1
  fi

  local final_output
  final_output="$(extract_host_final_output "$transcript" "$host")"
  if [[ "$final_output" != *"$marker"* ]]; then
    echo "  round-trip marker: MISSING from $host host's final output" >&2
    ok=1
  fi

  return $ok
}

# Verify a Claude prompt-a-peer transcript shows the skill loaded from this
# checkout, then apply the shared model and round-trip checks. Prints a
# per-check diagnostic to stderr on failure; returns 0 only if all checks pass.
# Args: <transcript> <repo_root> <skill_relpath> <expected_model> <pi_session> <marker>
verify_claude_success() {
  local transcript="$1" repo_root="$2" skill_relpath="$3" expected_model="$4"
  local session="$5" marker="$6"
  local ok=0

  local base_dir expected_base
  base_dir="$(extract_skill_base_dir "$transcript")"
  expected_base="$repo_root/$skill_relpath"
  if [ -z "$base_dir" ]; then
    echo "  skill base directory: MISSING (no 'Base directory for this skill:' event)" >&2
    ok=1
  elif [ "$(normalize_path "$base_dir")" != "$(normalize_path "$expected_base")" ]; then
    echo "  skill base directory: '$base_dir' does not match repo checkout '$expected_base'" >&2
    ok=1
  fi

  if ! verify_success "$session" "$transcript" claude "$expected_model" "$marker"; then
    ok=1
  fi

  return $ok
}
