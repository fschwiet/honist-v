import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import test from 'node:test';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';

import {
  extractReferences,
  formatDiagnostic,
  verifyRepository,
} from '../scripts/manifest-references.mjs';

const execFileAsync = promisify(execFile);
const cliPath = fileURLToPath(
  new URL('../scripts/verify-manifest-references.mjs', import.meta.url),
);

async function makeRepository() {
  const root = await mkdtemp(path.join(tmpdir(), 'honist-v-manifests-'));
  await mkdir(path.join(root, 'plugin/.claude-plugin'), {
    recursive: true,
  });
  await mkdir(path.join(root, 'plugin/.codex-plugin'), {
    recursive: true,
  });
  await mkdir(path.join(root, '.claude-plugin'), { recursive: true });
  await mkdir(path.join(root, '.agents/plugins'), { recursive: true });
  return root;
}

async function writeJson(root, relativePath, value) {
  await writeFile(path.join(root, relativePath), `${JSON.stringify(value, null, 2)}\n`);
}

test('extracts plugin skills and hooks with their expected kinds', () => {
  const result = extractReferences(
    'plugin',
    { skills: ['./skills', './skills-codex/'], hooks: './hooks/hooks.json' },
    'plugin/.claude-plugin/plugin.json',
    'plugin',
  );

  assert.deepEqual(result.diagnostics, []);
  assert.deepEqual(result.references, [
    {
      manifestPath: 'plugin/.claude-plugin/plugin.json',
      field: '$.skills[0]',
      value: './skills',
      baseDir: 'plugin',
      expectedKind: 'directory',
    },
    {
      manifestPath: 'plugin/.claude-plugin/plugin.json',
      field: '$.skills[1]',
      value: './skills-codex/',
      baseDir: 'plugin',
      expectedKind: 'directory',
    },
    {
      manifestPath: 'plugin/.claude-plugin/plugin.json',
      field: '$.hooks',
      value: './hooks/hooks.json',
      baseDir: 'plugin',
      expectedKind: 'file',
    },
  ]);
});

test('extracts current Claude and Codex marketplace sources', () => {
  const claude = extractReferences(
    'claude-marketplace',
    { plugins: [{ source: './plugin' }] },
    '.claude-plugin/marketplace.json',
    '.',
  );
  const codex = extractReferences(
    'codex-marketplace',
    {
      plugins: [{ source: { source: 'local', path: './plugin' } }],
    },
    '.agents/plugins/marketplace.json',
    '.',
  );

  assert.deepEqual(claude.diagnostics, []);
  assert.deepEqual(claude.references[0], {
    manifestPath: '.claude-plugin/marketplace.json',
    field: '$.plugins[0].source',
    value: './plugin',
    baseDir: '.',
    expectedKind: 'directory',
  });
  assert.deepEqual(codex.diagnostics, []);
  assert.deepEqual(codex.references[0], {
    manifestPath: '.agents/plugins/marketplace.json',
    field: '$.plugins[0].source.path',
    value: './plugin',
    baseDir: '.',
    expectedKind: 'directory',
  });
});

const invalidCases = [
  ['plugin document', 'plugin', null, '$'],
  ['skills container', 'plugin', { skills: {} }, '$.skills'],
  ['skills element', 'plugin', { skills: [null] }, '$.skills[0]'],
  ['hooks leaf', 'plugin', { hooks: null }, '$.hooks'],
  ['plugins container', 'claude-marketplace', { plugins: {} }, '$.plugins'],
  ['plugin element', 'claude-marketplace', { plugins: [null] }, '$.plugins[0]'],
  [
    'Claude remote source',
    'claude-marketplace',
    { plugins: [{ source: 'https://example.test/plugin' }] },
    '$.plugins[0].source',
  ],
  [
    'Claude null source',
    'claude-marketplace',
    { plugins: [{ source: null }] },
    '$.plugins[0].source',
  ],
  [
    'Codex source container',
    'codex-marketplace',
    { plugins: [{ source: null }] },
    '$.plugins[0].source',
  ],
  [
    'Codex discriminator',
    'codex-marketplace',
    { plugins: [{ source: { source: 'git', path: './plugin' } }] },
    '$.plugins[0].source.source',
  ],
  [
    'Codex null discriminator',
    'codex-marketplace',
    { plugins: [{ source: { source: null, path: './plugin' } }] },
    '$.plugins[0].source.source',
  ],
  [
    'Codex local path',
    'codex-marketplace',
    { plugins: [{ source: { source: 'local' } }] },
    '$.plugins[0].source.path',
  ],
  [
    'Codex null local path',
    'codex-marketplace',
    { plugins: [{ source: { source: 'local', path: null } }] },
    '$.plugins[0].source.path',
  ],
];

for (const [name, kind, document, field] of invalidCases) {
  test(`rejects invalid ${name}`, () => {
    const result = extractReferences(kind, document, 'manifest.json', '.');
    assert.equal(result.diagnostics.length, 1);
    assert.equal(result.diagnostics[0].field, field);
  });
}

test('skips absent optional path-bearing properties', () => {
  for (const [kind, document] of [
    ['plugin', {}],
    ['claude-marketplace', { plugins: [{}] }],
    ['codex-marketplace', { plugins: [{}] }],
  ]) {
    assert.deepEqual(extractReferences(kind, document, 'manifest.json', '.'), {
      references: [],
      diagnostics: [],
    });
  }
});

test('aggregates missing and wrong-kind targets across manifests', async (t) => {
  const root = await makeRepository();
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, 'plugin/skills'), { recursive: true });
  await writeFile(path.join(root, 'plugin/not-a-directory'), 'file');
  await mkdir(path.join(root, 'plugin/not-a-file'), { recursive: true });
  await writeJson(root, 'plugin/.claude-plugin/plugin.json', {
    skills: ['./skills', './missing-skill'],
    hooks: './not-a-file',
  });
  await writeJson(root, 'plugin/.codex-plugin/plugin.json', {
    skills: ['./not-a-directory'],
  });
  await writeJson(root, '.claude-plugin/marketplace.json', {
    plugins: [{ source: './missing-plugin' }],
  });
  await writeJson(root, '.agents/plugins/marketplace.json', {
    plugins: [{ source: { source: 'local', path: './plugin' } }],
  });

  const { diagnostics } = await verifyRepository(root);

  assert.equal(diagnostics.length, 4);
  assert.deepEqual(
    diagnostics.map(({ field }) => field),
    ['$.skills[1]', '$.hooks', '$.skills[0]', '$.plugins[0].source'],
  );
  assert.match(formatDiagnostic(diagnostics[0]), /missing-skill/);
  assert.match(formatDiagnostic(diagnostics[0]), /expected directory/);
});

test('reports parse failures at the document field and continues', async (t) => {
  const root = await makeRepository();
  t.after(() => rm(root, { recursive: true, force: true }));
  await writeFile(path.join(root, 'plugin/.claude-plugin/plugin.json'), '{invalid');

  const { diagnostics } = await verifyRepository(root);

  assert.equal(diagnostics.length, 4);
  assert.equal(diagnostics[0].field, '$');
  assert.match(diagnostics[0].message, /invalid JSON/);
  assert.equal(diagnostics.filter(({ message }) => message === 'manifest is missing').length, 3);
});

test('inspects valid references after an extraction failure', async (t) => {
  const root = await makeRepository();
  t.after(() => rm(root, { recursive: true, force: true }));
  await writeJson(root, 'plugin/.claude-plugin/plugin.json', {
    skills: [null, './missing-skill'],
  });
  await writeJson(root, 'plugin/.codex-plugin/plugin.json', {});
  await writeJson(root, '.claude-plugin/marketplace.json', {});
  await writeJson(root, '.agents/plugins/marketplace.json', {});

  const { diagnostics } = await verifyRepository(root);

  assert.equal(diagnostics.length, 2);
  assert.deepEqual(
    diagnostics.map(({ field }) => field),
    ['$.skills[0]', '$.skills[1]'],
  );
  assert.match(diagnostics[1].message, /missing/);
});

test('collects non-missing read and stat failures once each', async () => {
  const documents = new Map([
    [
      path.normalize('plugin/.claude-plugin/plugin.json'),
      JSON.stringify({ skills: ['./blocked-target'] }),
    ],
    [path.normalize('plugin/.codex-plugin/plugin.json'), JSON.stringify({})],
    [path.normalize('.claude-plugin/marketplace.json'), JSON.stringify({})],
  ]);
  const denied = Object.assign(new Error('access denied'), {
    code: 'EACCES',
  });
  const filesystem = {
    async readFile(filename) {
      const relative = path.normalize(path.relative('repo', filename));
      if (relative === path.normalize('.agents/plugins/marketplace.json')) {
        throw denied;
      }
      return documents.get(relative);
    },
    async stat() {
      throw denied;
    },
  };

  const { diagnostics } = await verifyRepository('repo', filesystem);

  assert.equal(diagnostics.length, 2);
  assert.match(diagnostics[0].message, /cannot be read/);
  assert.match(diagnostics[1].message, /cannot be inspected/);
});

test('classifies ENOTDIR as one missing-target diagnostic', async () => {
  const filesystem = {
    async readFile(filename) {
      if (filename.endsWith('plugin.json')) {
        return JSON.stringify({ skills: ['./missing/child'] });
      }
      return JSON.stringify({});
    },
    async stat() {
      throw Object.assign(new Error('not a directory'), {
        code: 'ENOTDIR',
      });
    },
  };

  const { diagnostics } = await verifyRepository('repo', filesystem);

  assert.equal(diagnostics.length, 2);
  assert.ok(diagnostics.every(({ message }) => message === 'referenced target is missing'));
});

async function writeValidRepository(root) {
  await mkdir(path.join(root, 'plugin/skills'), { recursive: true });
  await mkdir(path.join(root, 'plugin/skills-codex'), {
    recursive: true,
  });
  await mkdir(path.join(root, 'plugin/hooks'), { recursive: true });
  await writeFile(path.join(root, 'plugin/hooks/hooks.json'), '{}\n');
  await writeJson(root, 'plugin/.claude-plugin/plugin.json', {
    skills: ['./skills'],
    hooks: './hooks/hooks.json',
  });
  await writeJson(root, 'plugin/.codex-plugin/plugin.json', {
    skills: ['./skills-codex'],
  });
  await writeJson(root, '.claude-plugin/marketplace.json', {
    plugins: [{ source: './plugin' }],
  });
  await writeJson(root, '.agents/plugins/marketplace.json', {
    plugins: [{ source: { source: 'local', path: './plugin' } }],
  });
}

test('CLI exits zero and prints a success summary', async (t) => {
  const root = await makeRepository();
  t.after(() => rm(root, { recursive: true, force: true }));
  await writeValidRepository(root);

  const result = await execFileAsync(process.execPath, [cliPath], {
    cwd: root,
  });

  assert.equal(result.stderr, '');
  assert.match(result.stdout, /verified 5 manifest references/i);
});

test('CLI exits one after printing every diagnostic and a count', async (t) => {
  const root = await makeRepository();
  t.after(() => rm(root, { recursive: true, force: true }));
  await writeValidRepository(root);
  await rm(path.join(root, 'plugin/skills'), { recursive: true });
  await rm(path.join(root, 'plugin/hooks/hooks.json'));

  await assert.rejects(execFileAsync(process.execPath, [cliPath], { cwd: root }), (error) => {
    assert.equal(error.code, 1);
    assert.match(error.stderr, /\$\.skills\[0\]/);
    assert.match(error.stderr, /\$\.hooks/);
    assert.match(error.stderr, /2 manifest reference errors/i);
    return true;
  });
});
