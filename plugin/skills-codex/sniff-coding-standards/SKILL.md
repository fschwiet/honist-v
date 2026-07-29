---
name: sniff-coding-standards
description: Sniff selected files for coding-standard descriptions and references.
disable-model-invocation: true
---

# Sniff Coding Standards

Create a coding-standards report from the project's files.

## Process

1. Ask which files to sniff. Offer the default: every `.md` file recursively below the project root, excluding `docs/honist-v/`. Treat an empty answer as acceptance of the default. Resolve the user's answer to a concrete set of files within the project root.

2. Sort the selected files by their project-root-relative paths. Present the exact sorted list, one relative path per line, followed by the total file count. Ask the user to confirm this scope. Do not start sniffing until it is confirmed.

3. For each confirmed file, in the displayed order, run the `coding-standards-sniffer.toml` agent in this skill directory. Supply only that file's project-root-relative path as the agent input. Keep the agent's two output sections separate; each finding belongs to the input file it was produced from.

4. Write these two Markdown reports, replacing any prior versions:

   - `sniffed-coding-standard-descriptions.md`
   - `sniffed-coding-standard-references.md`

   Each report starts with a level-one heading matching its filename's subject: `# Coding-standard descriptions` or `# Coding-standard references`. Include a level-two heading with the project-root-relative path in backticks only for a file that reported at least one finding in that report's corresponding agent section. Copy its findings below the heading. When no selected file reported a finding for a report, write `None found.` below its level-one heading. Preserve the confirmed file order among the included files in both reports.

5. Read both reports back. Verify that each contains a level-two section for every and only the confirmed files with findings in its matching detector section, in the displayed scope order. Report the two paths and the sniffed-file count.
