#!/usr/bin/env pwsh
# Thin wrapper so the prompt-a-peer tests can be run from PowerShell under Git Bash.
# Forwards any arguments straight through to tests/prompt-a-peer/test.sh
# (see that file for the supported flags: --low --medium --high --claude --codex).
#
# A leading `--` separator is optional and stripped, so both of these work:
#   ./tests/run.ps1 -- --claude --medium
#   ./tests/run.ps1 --claude --medium

$ErrorActionPreference = 'Stop'

# Capture everything via the automatic $args variable rather than a param()
# block: PowerShell's parameter binder would otherwise reject flags like
# --medium as unknown parameters. Drop a single leading `--` separator.
$forwarded = @($args)
if ($forwarded.Count -gt 0 -and $forwarded[0] -eq '--') {
    $forwarded = $forwarded[1..($forwarded.Count - 1)]
}

# Use Git Bash explicitly: a bare `bash` on PATH usually resolves to the WSL
# stub (C:\Windows\System32\bash.exe), which uses /mnt/c paths and lacks the
# claude/codex/jq CLIs this test needs.
$bash = "C:\Program Files\Git\bin\bash.exe"

& $bash "$PSScriptRoot/prompt-a-peer/test.sh" @forwarded
exit $LASTEXITCODE
