const VERSION_PATTERN = /^(\d+)\.(\d+)\.(\d+)$/;

function parseVersion(value) {
  if (typeof value !== 'string') return undefined;
  const match = VERSION_PATTERN.exec(value);
  if (!match) return undefined;

  const [major, minor, patch] = match.slice(1).map(Number);
  if (![major, minor, patch].every(Number.isSafeInteger)) return undefined;
  // Rejects leading zeros (e.g. "01") and any precision loss from Number(),
  // since a canonical value round-trips back to the original string.
  if (`${major}.${minor}.${patch}` !== value) return undefined;

  return { major, minor, patch };
}

export function computeVersionBump(entries) {
  const parsed = entries.map((entry) => ({ ...entry, parsed: parseVersion(entry.value) }));

  for (const entry of parsed) {
    if (!entry.parsed) {
      return {
        ok: false,
        message: `${entry.label} has an invalid version: ${JSON.stringify(entry.value)} (expected "x.y.z")`,
      };
    }
  }

  const [first, second] = parsed;
  if (first.value !== second.value) {
    return {
      ok: false,
      message: `plugin.json versions disagree: ${first.label} has ${first.value}, ${second.label} has ${second.value}`,
    };
  }

  const { major, minor, patch } = first.parsed;
  return { ok: true, version: `${major}.${minor}.${patch + 1}` };
}
