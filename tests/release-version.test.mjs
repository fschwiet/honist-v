import assert from 'node:assert/strict';
import test from 'node:test';

import { computeVersionBump } from '../scripts/release-version.mjs';

test('bumps the patch version when both entries match', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.0.3' },
    { label: 'b.json', value: '0.0.3' },
  ]);

  assert.deepEqual(result, { ok: true, version: '0.0.4' });
});

test('bumps a double-digit patch version', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '1.2.9' },
    { label: 'b.json', value: '1.2.9' },
  ]);

  assert.deepEqual(result, { ok: true, version: '1.2.10' });
});

test('reports a mismatch between the two versions', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.0.3' },
    { label: 'b.json', value: '0.0.4' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json has 0\.0\.3/);
  assert.match(result.message, /b\.json has 0\.0\.4/);
});

test('rejects a version missing from a manifest', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: undefined },
    { label: 'b.json', value: '0.0.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a non-string version value', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: null },
    { label: 'b.json', value: '0.0.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a version with a pre-release suffix', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.0.3-beta' },
    { label: 'b.json', value: '0.0.3-beta' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a version with the wrong number of components', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.3' },
    { label: 'b.json', value: '0.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a version component with a leading zero', () => {
  const result = computeVersionBump([
    { label: 'a.json', value: '0.01.3' },
    { label: 'b.json', value: '0.01.3' },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});

test('rejects a patch number outside the safe integer range', () => {
  const huge = String(Number.MAX_SAFE_INTEGER + 1);
  const result = computeVersionBump([
    { label: 'a.json', value: `0.0.${huge}` },
    { label: 'b.json', value: `0.0.${huge}` },
  ]);

  assert.equal(result.ok, false);
  assert.match(result.message, /a\.json/);
});
