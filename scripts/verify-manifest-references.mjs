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
