# Manifest Reference Verification Design

## Goal

Extend the repository verification pipeline so it fails when a file or
directory referenced by one of the repository's current plugin or marketplace
manifest fields does not exist or has the wrong filesystem kind.

The verifier will support only the path-bearing fields currently used by this
repository. Supporting other fields from the broader Claude or Codex manifest
formats is outside this design.

## Supported Manifests and References

The verifier will have an explicit declaration for these manifests and fields:

| Manifest | Field | Resolution base | Expected kind |
| --- | --- | --- | --- |
| `plugin/.claude-plugin/plugin.json` | `skills[]` | `plugin/` | Directory |
| `plugin/.claude-plugin/plugin.json` | `hooks` | `plugin/` | File |
| `plugin/.codex-plugin/plugin.json` | `skills[]` | `plugin/` | Directory |
| `.claude-plugin/marketplace.json` | `plugins[].source` | Repository root | Directory |
| `.agents/plugins/marketplace.json` | `plugins[].source.path` when `source.source` is `local` | Repository root | Directory |

The verifier will preserve these existing relative-path semantics. It will not
add path-containment or other security-policy checks.

## Architecture

Add a dependency-free Node CLI dedicated to manifest reference verification.
The CLI will run from the repository root and keep three responsibilities
separate:

1. Load and parse the expected manifests.
2. Convert supported manifest fields into uniform reference records.
3. Resolve and validate every reference against the filesystem.

Each reference record will contain:

- The source manifest path.
- The JSON field location, including array indexes.
- The original reference value.
- The base directory used for resolution.
- The expected filesystem kind: file or directory.

Manifest-specific extractors will contain the knowledge of current JSON shapes.
Filesystem validation will operate only on the uniform records, keeping schema
interpretation independent from target inspection.

`package.json` will expose the CLI through a named script. `pnpm verify` will
invoke that script in addition to the existing format, JavaScript lint, and
Markdown lint stages.

## Data Flow

For each expected manifest, the verifier will:

1. Read and parse the JSON.
2. Validate the types of supported path-bearing fields.
3. Extract all supported references into uniform records.
4. Resolve each reference against its declared base directory.
5. Inspect every resolved target, without stopping after a failure.
6. Print all collected diagnostics.
7. Exit nonzero when one or more checks failed; otherwise, print a concise
   success message and exit zero.

## Failure Behavior

The following conditions are verification failures:

- An expected manifest is missing.
- An expected manifest contains invalid JSON.
- A supported field has the wrong JSON type.
- A referenced target does not exist.
- A referenced target exists but is not the expected file or directory kind.

Each diagnostic will identify:

- The manifest path.
- The JSON field location.
- The original reference, when available.
- The expected kind, when applicable.
- The resolved target path, when applicable.
- A concise description of the failure.

All failures will be reported in one run, followed by a count summary. The
verifier will not fail fast.

## Testing

Use Node's built-in test runner so the feature adds no runtime or development
dependency. Tests will create isolated temporary repository layouts and cover:

- Valid references for every supported field shape.
- Correct handling of file and directory targets.
- Missing referenced targets.
- Existing targets of the wrong kind.
- Missing and malformed manifests.
- Supported fields with incorrect JSON types.
- Multiple simultaneous failures reported by a single run.
- Zero and nonzero CLI exit behavior.

Running the new verifier against the repository's real manifests through
`pnpm verify` will serve as the acceptance test that all committed references
resolve correctly.

## Documentation

Update the README verification section to include the manifest-reference stage
and remove the statement that the pipeline is linting only. Document the new
named package script alongside the existing verification scripts.

## Out of Scope

- Full validation against Claude or Codex manifest schemas.
- Discovering additional path-bearing fields automatically.
- Validating remote marketplace sources.
- Enforcing that referenced paths remain within the repository.
- Changing existing manifest path-resolution conventions.
