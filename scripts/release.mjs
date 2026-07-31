import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

import { computeVersionBump } from './release-version.mjs';

const PLUGIN_MANIFESTS = ['plugin/.claude-plugin/plugin.json', 'plugin/.codex-plugin/plugin.json'];

function runCommand(cmd, args, { shell = false } = {}) {
  // Node emits DEP0190 if shell:true is combined with a non-empty args
  // array (args get concatenated into the shell string unescaped). Since
  // our shell:true callers never pass untrusted input, fold args into the
  // command string ourselves and call with an empty args array instead.

  // We can't always join the args because when shell is false cmd is treated
  // as a command name.

  const result = shell
    ? spawnSync([cmd, ...args].join(' '), [], { stdio: 'inherit', shell })
    : spawnSync(cmd, args, { stdio: 'inherit', shell });
  return result.error === undefined && result.signal === null && result.status === 0;
}

function captureCommand(cmd, args) {
  const result = spawnSync(cmd, args, { encoding: 'utf8' });
  if (result.error !== undefined || result.signal !== null || result.status !== 0) {
    if (result.stderr) process.stderr.write(result.stderr);
    return { ok: false };
  }
  return { ok: true, stdout: result.stdout.trim() };
}

function verifyBuild() {
  // pnpm resolves to a .cmd shim on Windows, which Node can only spawn via
  // a shell. Its arguments never contain spaces, so this is safe — unlike
  // git commands below, which must NOT use shell: true (see Global
  // Constraints: it breaks multi-word arguments like the commit message).
  return runCommand('pnpm', ['verify'], { shell: true });
}

function checkMainSynced() {
  const status = captureCommand('git', ['status', '--porcelain']);
  if (!status.ok) return false;
  if (status.stdout !== '') {
    console.error('worktree has uncommitted changes — commit or stash first.');
    return false;
  }

  const branch = captureCommand('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (!branch.ok) return false;
  if (branch.stdout !== 'main') {
    console.error(`current branch is "${branch.stdout}", not "main" — switch to main first.`);
    return false;
  }

  if (!runCommand('git', ['fetch', 'origin', 'main'])) return false;

  const counts = captureCommand('git', [
    'rev-list',
    '--left-right',
    '--count',
    'origin/main...HEAD',
  ]);
  if (!counts.ok) return false;
  const [left, right] = counts.stdout.split(/\s+/).map(Number);
  if (left > 0 && right > 0) {
    console.error('main has diverged from origin/main — reconcile first.');
    return false;
  }
  if (left > 0) {
    console.error('main is behind origin/main — pull/rebase first.');
    return false;
  }

  return true;
}

function bumpPatchVersion() {
  const entries = PLUGIN_MANIFESTS.map((filePath) => {
    const document = JSON.parse(readFileSync(filePath, 'utf8'));
    return { label: filePath, value: document.version, filePath, document };
  });

  const result = computeVersionBump(entries);
  if (!result.ok) {
    console.error(result.message);
    return undefined;
  }

  for (const entry of entries) {
    entry.document.version = result.version;
    writeFileSync(entry.filePath, `${JSON.stringify(entry.document, null, 2)}\n`);
  }

  if (!runCommand('git', ['add', ...PLUGIN_MANIFESTS])) return undefined;
  if (!runCommand('git', ['commit', '-m', `Bump version to ${result.version}`])) return undefined;

  return result.version;
}

function pushToOrigin() {
  return runCommand('git', ['push', 'origin', 'main']);
}

function main() {
  if (!verifyBuild()) {
    process.exitCode = 1;
    return;
  }

  if (!checkMainSynced()) {
    process.exitCode = 1;
    return;
  }

  const version = bumpPatchVersion();
  if (version === undefined) {
    process.exitCode = 1;
    return;
  }

  if (!pushToOrigin()) {
    console.error(
      `Version bumped to ${version} and committed locally, but the push failed. ` +
        'Push it manually once the problem is resolved: git push origin main',
    );
    process.exitCode = 1;
    return;
  }

  console.log(`Released ${version} and pushed to origin/main.`);
}

main();
