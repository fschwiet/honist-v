# Manifest Reference Verification Implementation Plan

**Goal:** Add a verification stage that reports every missing, unreadable, or incorrectly typed file and directory referenced by the repository's current plugin and marketplace manifests.

**Architecture:** A dependency-free ESM module will own explicit manifest declarations, schema-specific extraction, filesystem inspection, and diagnostic formatting. A thin CLI will run that module from the repository root; Node's built-in test runner will exercise pure extraction, injected filesystem failures, and process exit behavior.

**Tech Stack:** Node.js 18 or newer, ECMAScript modules, `node:fs/promises`, `node:test`, pnpm 11

## Global Constraints

- Support only the path-bearing fields currently used by this repository.
- Add no runtime or development dependency.
- Preserve the existing resolution bases: plugin references resolve from `plugin/`; marketplace references resolve from the repository root.
- Enforce `skills` and marketplace sources as directories and `hooks` as a file.
- Collect all manifest and target failures before returning.
- Emit exactly one diagnostic per failed filesystem operation.
- Do not enforce repository containment or validate remote marketplace sources.

---

## File Map

- Create `scripts/manifest-references.mjs`: manifest declarations, extractors, filesystem verification, and diagnostic formatting.
- Create `scripts/verify-manifest-references.mjs`: process-facing CLI and exit-code handling.
- Create `tests/manifest-references.test.mjs`: pure extractor tests, isolated temporary-repository tests, injected filesystem-error tests, and CLI process tests.
- Modify `package.json`: add `verify:manifest-references` and `test:manifest-references`, then wire both into `verify`.
- Modify `README.md`: document the expanded pipeline and both new scripts.

### Task 1: Extract Typed References From Current Manifest Shapes

**Files:**

- Create: `scripts/manifest-references.mjs`
- Create: `tests/manifest-references.test.mjs`

**Interfaces:**

- Consumes: Parsed JSON values and manifest metadata supplied by callers.
- Produces: `extractReferences(kind, document, manifestPath, baseDir) -> { references, diagnostics }`, where each reference is `{ manifestPath, field, value, baseDir, expectedKind }` and each diagnostic is `{ manifestPath, field, value?, expectedKind?, resolvedPath?, message }`.

- [ ] **Step 1: Write failing tests for valid current fields**

Create `tests/manifest-references.test.mjs`:

```js
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
```

- [ ] **Step 2: Run the extractor tests to verify they fail**

Run:

```powershell
node --test tests/manifest-references.test.mjs
```

Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `scripts/manifest-references.mjs`.

- [ ] **Step 3: Implement the reference records and current extractors**

Create `scripts/manifest-references.mjs`:

```js
function diagnostic(manifestPath, field, message, details = {}) {
  return { manifestPath, field, ...details, message };
}

function requireArray(value, manifestPath, field, diagnostics) {
  if (!Array.isArray(value)) {
    diagnostics.push(diagnostic(manifestPath, field, 'expected an array'));
    return undefined;
  }
  return value;
}

function requireObject(value, manifestPath, field, diagnostics) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    diagnostics.push(diagnostic(manifestPath, field, 'expected an object'));
    return undefined;
  }
  return value;
}

function addStringReference(
  references,
  diagnostics,
  { manifestPath, field, value, baseDir, expectedKind },
) {
  if (typeof value !== 'string') {
    diagnostics.push(
      diagnostic(manifestPath, field, 'expected a string', {
        value,
        expectedKind,
      }),
    );
    return;
  }
  references.push({
    manifestPath,
    field,
    value,
    baseDir,
    expectedKind,
  });
}

function extractPlugin(document, manifestPath, baseDir) {
  const references = [];
  const diagnostics = [];

  if (Object.hasOwn(document, 'skills')) {
    const skills = requireArray(document.skills, manifestPath, '$.skills', diagnostics);
    skills?.forEach((value, index) => {
      addStringReference(references, diagnostics, {
        manifestPath,
        field: `$.skills[${index}]`,
        value,
        baseDir,
        expectedKind: 'directory',
      });
    });
  }

  if (Object.hasOwn(document, 'hooks')) {
    addStringReference(references, diagnostics, {
      manifestPath,
      field: '$.hooks',
      value: document.hooks,
      baseDir,
      expectedKind: 'file',
    });
  }

  return { references, diagnostics };
}

function extractMarketplace(document, manifestPath, baseDir, kind) {
  const references = [];
  const diagnostics = [];

  if (!Object.hasOwn(document, 'plugins')) {
    return { references, diagnostics };
  }
  const plugins = requireArray(document.plugins, manifestPath, '$.plugins', diagnostics);
  plugins?.forEach((value, index) => {
    const pluginField = `$.plugins[${index}]`;
    const plugin = requireObject(value, manifestPath, pluginField, diagnostics);
    if (!plugin || !Object.hasOwn(plugin, 'source')) return;

    if (kind === 'claude-marketplace') {
      const source = plugin.source;
      if (typeof source !== 'string' || !source.startsWith('./')) {
        diagnostics.push(
          diagnostic(
            manifestPath,
            `${pluginField}.source`,
            'expected a local source string beginning with "./"',
            { value: source, expectedKind: 'directory' },
          ),
        );
        return;
      }
      addStringReference(references, diagnostics, {
        manifestPath,
        field: `${pluginField}.source`,
        value: source,
        baseDir,
        expectedKind: 'directory',
      });
      return;
    }

    const sourceField = `${pluginField}.source`;
    const source = requireObject(plugin.source, manifestPath, sourceField, diagnostics);
    if (!source) return;
    if (source.source !== 'local') {
      diagnostics.push(
        diagnostic(
          manifestPath,
          `${sourceField}.source`,
          'expected the supported discriminator "local"',
          { value: source.source },
        ),
      );
      return;
    }
    addStringReference(references, diagnostics, {
      manifestPath,
      field: `${sourceField}.path`,
      value: source.path,
      baseDir,
      expectedKind: 'directory',
    });
  });

  return { references, diagnostics };
}

export function extractReferences(kind, document, manifestPath, baseDir) {
  if (document === null || typeof document !== 'object' || Array.isArray(document)) {
    return {
      references: [],
      diagnostics: [diagnostic(manifestPath, '$', 'expected a JSON object')],
    };
  }
  if (kind === 'plugin') {
    return extractPlugin(document, manifestPath, baseDir);
  }
  return extractMarketplace(document, manifestPath, baseDir, kind);
}
```

- [ ] **Step 4: Run the extractor tests to verify they pass**

Run:

```powershell
node --test tests/manifest-references.test.mjs
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Add failing table tests for every type boundary**

Append to `tests/manifest-references.test.mjs`:

```js
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
    'Codex local path',
    'codex-marketplace',
    { plugins: [{ source: { source: 'local' } }] },
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
```

- [ ] **Step 6: Run the type-boundary tests**

Run:

```powershell
node --test tests/manifest-references.test.mjs
```

Expected: PASS, 13 tests with the exact `$`-based field paths asserted above.

- [ ] **Step 7: Commit the extraction slice**

```powershell
git add scripts/manifest-references.mjs tests/manifest-references.test.mjs
git commit -m "Add manifest reference extraction"
```

### Task 2: Verify All Declared Manifests and Filesystem Targets

**Files:**

- Modify: `scripts/manifest-references.mjs`
- Modify: `tests/manifest-references.test.mjs`

**Interfaces:**

- Consumes: `extractReferences(kind, document, manifestPath, baseDir)` from Task 1 and an optional filesystem object exposing async `readFile(path, encoding)` and `stat(path)`.
- Produces: `verifyRepository(rootDir, filesystem = fs) -> Promise<Diagnostic[]>` and `formatDiagnostic(diagnostic) -> string`.

- [ ] **Step 1: Write failing tests for aggregation, kind enforcement, and formatting**

Append these imports and helpers to `tests/manifest-references.test.mjs`:

```js
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

import { formatDiagnostic, verifyRepository } from '../scripts/manifest-references.mjs';

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
```

Append the tests:

```js
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

  const diagnostics = await verifyRepository(root);

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

  const diagnostics = await verifyRepository(root);

  assert.equal(diagnostics.length, 4);
  assert.equal(diagnostics[0].field, '$');
  assert.match(diagnostics[0].message, /invalid JSON/);
  assert.equal(diagnostics.filter(({ message }) => message === 'manifest is missing').length, 3);
});
```

- [ ] **Step 2: Run the verification tests to verify they fail**

Run:

```powershell
node --test --test-name-pattern="aggregates|parse failures" tests/manifest-references.test.mjs
```

Expected: FAIL because `verifyRepository` and `formatDiagnostic` are not exported.

- [ ] **Step 3: Implement declarations, loading, inspection, and formatting**

Add at the top of `scripts/manifest-references.mjs`:

```js
import fs from 'node:fs/promises';
import path from 'node:path';

const manifests = [
  {
    path: 'plugin/.claude-plugin/plugin.json',
    baseDir: 'plugin',
    kind: 'plugin',
  },
  {
    path: 'plugin/.codex-plugin/plugin.json',
    baseDir: 'plugin',
    kind: 'plugin',
  },
  {
    path: '.claude-plugin/marketplace.json',
    baseDir: '.',
    kind: 'claude-marketplace',
  },
  {
    path: '.agents/plugins/marketplace.json',
    baseDir: '.',
    kind: 'codex-marketplace',
  },
];
```

Append to `scripts/manifest-references.mjs`:

```js
function filesystemMessage(error, missingMessage, otherMessage) {
  return error?.code === 'ENOENT' || error?.code === 'ENOTDIR' ? missingMessage : otherMessage;
}

export async function verifyRepository(rootDir, filesystem = fs) {
  const diagnostics = [];
  const references = [];

  for (const manifest of manifests) {
    const absoluteManifest = path.resolve(rootDir, manifest.path);
    let source;
    try {
      source = await filesystem.readFile(absoluteManifest, 'utf8');
    } catch (error) {
      diagnostics.push(
        diagnostic(
          manifest.path,
          '$',
          filesystemMessage(
            error,
            'manifest is missing',
            `manifest cannot be read: ${error.message}`,
          ),
        ),
      );
      continue;
    }

    let document;
    try {
      document = JSON.parse(source);
    } catch (error) {
      diagnostics.push(diagnostic(manifest.path, '$', `invalid JSON: ${error.message}`));
      continue;
    }

    const extracted = extractReferences(manifest.kind, document, manifest.path, manifest.baseDir);
    references.push(...extracted.references);
    diagnostics.push(...extracted.diagnostics);
  }

  for (const reference of references) {
    const resolvedPath = path.resolve(rootDir, reference.baseDir, reference.value);
    let stats;
    try {
      stats = await filesystem.stat(resolvedPath);
    } catch (error) {
      diagnostics.push(
        diagnostic(
          reference.manifestPath,
          reference.field,
          filesystemMessage(
            error,
            'referenced target is missing',
            `referenced target cannot be inspected: ${error.message}`,
          ),
          { ...reference, resolvedPath },
        ),
      );
      continue;
    }

    const matches = reference.expectedKind === 'file' ? stats.isFile() : stats.isDirectory();
    if (!matches) {
      diagnostics.push(
        diagnostic(reference.manifestPath, reference.field, `expected ${reference.expectedKind}`, {
          ...reference,
          resolvedPath,
        }),
      );
    }
  }

  return diagnostics;
}

export function formatDiagnostic(item) {
  const details = [
    `${item.manifestPath}:${item.field}`,
    item.value === undefined ? undefined : `reference ${JSON.stringify(item.value)}`,
    item.expectedKind ? `expected ${item.expectedKind}` : undefined,
    item.resolvedPath ? `resolved ${item.resolvedPath}` : undefined,
  ].filter(Boolean);
  return `${details.join(' | ')} | ${item.message}`;
}
```

- [ ] **Step 4: Run the aggregation tests to verify they pass**

Run:

```powershell
node --test --test-name-pattern="aggregates|parse failures" tests/manifest-references.test.mjs
```

Expected: PASS, 2 selected tests.

- [ ] **Step 5: Write failing injected-filesystem tests for unreadable operations**

Append to `tests/manifest-references.test.mjs`:

```js
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

  const diagnostics = await verifyRepository('repo', filesystem);

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

  const diagnostics = await verifyRepository('repo', filesystem);

  assert.equal(diagnostics.length, 2);
  assert.ok(diagnostics.every(({ message }) => message === 'referenced target is missing'));
});
```

- [ ] **Step 6: Run all module tests**

Run:

```powershell
node --test tests/manifest-references.test.mjs
```

Expected: PASS, 17 tests. Diagnostics must remain in manifest declaration order, followed by reference inspection order.

- [ ] **Step 7: Commit the verification slice**

```powershell
git add scripts/manifest-references.mjs tests/manifest-references.test.mjs
git commit -m "Verify manifest reference targets"
```

### Task 3: Add the CLI and Its Exit Contract

**Files:**

- Create: `scripts/verify-manifest-references.mjs`
- Modify: `tests/manifest-references.test.mjs`

**Interfaces:**

- Consumes: `verifyRepository(process.cwd())` and `formatDiagnostic()` from Task 2.
- Produces: CLI stdout success summary, stderr aggregated failure report, and process exit status 0 or 1.

- [ ] **Step 1: Write failing process tests for success and aggregate failure output**

Add these imports to `tests/manifest-references.test.mjs`:

```js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';

const execFileAsync = promisify(execFile);
const cliPath = fileURLToPath(
  new URL('../scripts/verify-manifest-references.mjs', import.meta.url),
);
```

Append:

```js
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
```

- [ ] **Step 2: Run the CLI tests to verify they fail**

Run:

```powershell
node --test --test-name-pattern="CLI exits" tests/manifest-references.test.mjs
```

Expected: FAIL with `MODULE_NOT_FOUND` for `scripts/verify-manifest-references.mjs`.

- [ ] **Step 3: Return the checked-reference count and implement the thin CLI**

Change the end of `verifyRepository` in `scripts/manifest-references.mjs` from:

```js
  return diagnostics;
}
```

to:

```js
  return { checkedCount: references.length, diagnostics };
}
```

Update every test call from:

```js
const diagnostics = await verifyRepository(root);
```

to:

```js
const { diagnostics } = await verifyRepository(root);
```

Apply the same destructuring to calls that pass an injected filesystem.

Create `scripts/verify-manifest-references.mjs`:

```js
import { formatDiagnostic, verifyRepository } from './manifest-references.mjs';

const { checkedCount, diagnostics } = await verifyRepository(process.cwd());

if (diagnostics.length > 0) {
  for (const item of diagnostics) {
    console.error(formatDiagnostic(item));
  }
  const noun = diagnostics.length === 1 ? 'error' : 'errors';
  console.error(`${diagnostics.length} manifest reference ${noun}`);
  process.exitCode = 1;
} else {
  const noun = checkedCount === 1 ? 'reference' : 'references';
  console.log(`Verified ${checkedCount} manifest ${noun}.`);
}
```

- [ ] **Step 4: Run all tests to verify the return-type migration and CLI pass**

Run:

```powershell
node --test tests/manifest-references.test.mjs
```

Expected: PASS, 19 tests.

- [ ] **Step 5: Run lint and formatting checks**

Run:

```powershell
pnpm exec prettier --check scripts/manifest-references.mjs scripts/verify-manifest-references.mjs tests/manifest-references.test.mjs
pnpm exec eslint scripts/manifest-references.mjs scripts/verify-manifest-references.mjs tests/manifest-references.test.mjs
```

Expected: both commands exit 0. If Prettier reports differences, run the exact formatter and repeat both checks:

```powershell
pnpm exec prettier --write scripts/manifest-references.mjs scripts/verify-manifest-references.mjs tests/manifest-references.test.mjs
```

- [ ] **Step 6: Commit the CLI slice**

```powershell
git add scripts/manifest-references.mjs scripts/verify-manifest-references.mjs tests/manifest-references.test.mjs
git commit -m "Add manifest reference verifier CLI"
```

### Task 4: Wire Verification Into pnpm and Document It

**Files:**

- Modify: `package.json`
- Modify: `README.md`

**Interfaces:**

- Consumes: `scripts/verify-manifest-references.mjs` and `tests/manifest-references.test.mjs`.
- Produces: `pnpm verify:manifest-references`, `pnpm test:manifest-references`, and an expanded `pnpm verify`.

- [ ] **Step 1: Add package scripts and make the full pipeline executable**

Replace the `scripts` object in `package.json` with:

```json
"scripts": {
  "verify": "pnpm format:check && pnpm lint && pnpm lint:md && pnpm test:manifest-references && pnpm verify:manifest-references",
  "verify:manifest-references": "node scripts/verify-manifest-references.mjs",
  "test:manifest-references": "node --test tests/manifest-references.test.mjs",
  "lint": "eslint .",
  "lint:md": "markdownlint-cli2",
  "format": "prettier --write .",
  "format:check": "prettier --check ."
}
```

- [ ] **Step 2: Run the named test and real-manifest acceptance scripts**

Run:

```powershell
pnpm test:manifest-references
pnpm verify:manifest-references
```

Expected: the test script reports 19 passing tests; the verifier exits 0 and reports `Verified 12 manifest references.` based on the four current manifests.

- [ ] **Step 3: Update the README verification section**

Replace the existing `## Verification` section through its scripts table with:

````markdown
## Verification

The verification pipeline checks formatting, JavaScript and Markdown lint, manifest-reference behavior, and every file or directory referenced by the current plugin and marketplace manifests:

```bash
pnpm install
pnpm verify
```

Other useful scripts:

| Script                            | Description                             |
| --------------------------------- | --------------------------------------- |
| `pnpm verify:manifest-references` | Check references in committed manifests |
| `pnpm test:manifest-references`   | Test manifest-reference verification    |
| `pnpm lint`                       | Run ESLint                              |
| `pnpm lint:md`                    | Lint Markdown with markdownlint         |
| `pnpm format`                     | Format all files with Prettier          |
| `pnpm format:check`               | Check formatting without writing        |
````

Keep the existing CI paragraph immediately after the table.

- [ ] **Step 4: Run the complete verification pipeline**

Run:

```powershell
pnpm verify
```

Expected: format check, ESLint, Markdown lint, 19 Node tests, and the real-manifest check all pass.

- [ ] **Step 5: Inspect the final diff for unintended generated files**

Run:

```powershell
git status --short
git diff --check
git diff -- package.json README.md scripts tests/manifest-references.test.mjs
```

Expected: only the five planned implementation files are changed or untracked, and `git diff --check` prints nothing.

- [ ] **Step 6: Commit the pipeline and documentation**

```powershell
git add package.json README.md scripts/manifest-references.mjs scripts/verify-manifest-references.mjs tests/manifest-references.test.mjs
git commit -m "Add manifest reference verification pipeline"
```
