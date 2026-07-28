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
| `.claude-plugin/marketplace.json` | String `plugins[].source` | Repository root | Directory |
| `.agents/plugins/marketplace.json` | `plugins[].source.path` when `source.source` is `local` | Repository root | Directory |

The verifier will preserve these existing relative-path semantics. It will not
add path-containment or other security-policy checks. Only the current local
marketplace source forms are supported; introducing a remote form will require
extending the verifier and will fail until then.

## Extraction and Type Rules

Missing optional path-bearing properties are skipped. A property that is
present with a `null` value is present, not missing, and fails when the expected
type is different.

The manifest-specific extractors will apply these rules:

| JSON location | Required type and behavior |
| --- | --- |
| Plugin manifest `skills` | When present, must be an array. |
| Plugin manifest `skills[]` | Every element must be a string and becomes a directory reference. |
| Plugin manifest `hooks` | When present, must be a string and becomes a file reference. |
| Marketplace `plugins` | When present, must be an array. |
| Marketplace `plugins[]` | Every element must be an object. |
| Claude marketplace `plugins[].source` | When present, must be a string and becomes a directory reference. |
| Codex marketplace `plugins[].source` | When present, must be an object whose `source` discriminator is the string `local`; other source forms are unsupported. |
| Codex marketplace local `plugins[].source.path` | Must be a string and becomes a directory reference. |

These rules deliberately reject unimplemented remote source forms rather than
silently accepting a manifest that the reference verifier did not check.

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

`package.json` will expose the CLI as `verify:manifest-references` and its test
suite as `test:manifest-references`. `pnpm verify` will invoke both scripts in
addition to the existing format, JavaScript lint, and Markdown lint stages.

## Data Flow

For each expected manifest, the verifier will:

1. Read and parse the JSON, collecting rather than throwing read failures.
2. Validate the types of supported path-bearing fields.
3. Extract all supported references into uniform records.
4. Resolve each reference against its declared base directory.
5. Inspect every resolved target, collecting rather than throwing filesystem
   inspection failures.
6. Print all collected diagnostics.
7. Exit nonzero when one or more checks failed; otherwise, print a concise
   success message and exit zero.

## Failure Behavior

The following conditions are verification failures:

- An expected manifest is missing.
- An expected manifest cannot be read.
- An expected manifest contains invalid JSON.
- A supported field is present but has the wrong JSON type.
- A local source uses an unsupported shape.
- A referenced target does not exist.
- A referenced target exists but is not the expected file or directory kind.
- A referenced target cannot be inspected.

Each diagnostic will identify:

- The manifest path.
- The JSON field location when the failure concerns a field; document-level
  failures will use `$`.
- The original reference, when available.
- The expected kind, when applicable.
- The resolved target path, when applicable.
- A concise description of the failure.

All expected manifests and extracted references will be checked even after
read, parse, extraction, or filesystem failures. All failures will be reported
in one run, followed by a count summary. Unexpected programmer errors may still
terminate the process.

## Testing

Use Node's built-in test runner so the feature adds no runtime or development
dependency. Tests will create isolated temporary repository layouts and cover:

- Valid references for every supported field shape.
- Correct handling of file and directory targets.
- Missing referenced targets.
- Existing targets of the wrong kind.
- Missing and malformed manifests.
- Unreadable manifests and targets that cannot be inspected.
- Container properties, array elements, discriminators, and leaf fields with
  incorrect JSON types, including explicit `null` values.
- Unsupported marketplace source forms failing explicitly.
- Multiple simultaneous failures reported by a single run.
- Zero and nonzero CLI exit behavior.

`pnpm verify` will run both the isolated Node test suite and the new verifier
against the repository's real manifests. The latter is the acceptance test that
all committed references resolve correctly.

## Documentation

Update the README verification section to include the manifest-reference stage
and remove the statement that the pipeline is linting only. Document the new
named package script alongside the existing verification scripts.

## Out of Scope

- Full validation against Claude or Codex manifest schemas.
- Requiring optional path-bearing fields to be present.
- Discovering additional path-bearing fields automatically.
- Supporting or validating remote marketplace sources.
- Enforcing that referenced paths remain within the repository.
- Changing existing manifest path-resolution conventions.
