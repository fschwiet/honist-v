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

  return { checkedCount: references.length, diagnostics };
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
