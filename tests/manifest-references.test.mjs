import assert from 'node:assert/strict';
import test from 'node:test';

import { extractReferences } from '../scripts/manifest-references.mjs';

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
