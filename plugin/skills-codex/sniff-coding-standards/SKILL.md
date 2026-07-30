---
name: sniff-coding-standards
description: Sniff selected files for coding-standard descriptions and references.
disable-model-invocation: true
---

# Sniff Coding Standards

Create a coding-standards report from the project's files.

## Process

1. Ask the user to confirm the default selection—every `.md` file recursively below the project root, excluding `docs/honist-v/`—or say which files to sniff instead. Resolve the response to a concrete set of files within the project root.

2. Sort the selected files by their project-root-relative paths. Present the exact sorted list, one relative path per line, followed by the total file count. Ask the user to confirm this scope. Do not start sniffing until it is confirmed.

3. For each confirmed file, in the displayed order, spawn a separate, new native subagent. Do not reuse a subagent from a prior file and do not call `followup_task`; each file must start in a fresh child thread with no prior-file context.

   - Use the task name `coding-standards-sniffer`, model `gpt-5.6-luna`, and medium reasoning effort.
   - If the host supports a per-agent sandbox setting, set it to read-only. Otherwise, the subagent inherits the parent sandbox; its instructions must still prohibit modifications.
   - Give the subagent these exact instructions followed by the supplied file's project-root-relative path:

     ```text
     You are a focused, read-only coding-standards detector.

     Load the supplied file and examine its complete contents. Do not inspect other files and do not modify anything.

     Identify two distinct kinds of findings:
     - Coding-standard descriptions: prose that states, explains, or prescribes a coding convention, rule, practice, or requirement.
     - Coding-standard references: mentions or links to a coding-standard document, guide, policy, style guide, linter rule set, formatter configuration, or other external standard.

     Return exactly these two sections, in this order:

     ## Coding-standard descriptions
     - Line <number>: <concise description or quoted text>

     ## Coding-standard references
     - Line <number>: <reference text>

     Use the line where each finding begins. Keep findings in source order within each section. Do not report unrelated development guidance or infer standards. If a section has no findings, write `None found.` below its heading.
     ```

   - Capture only the agent's final response, excluding CLI/session transcripts, tool logs, and echoed prompts.
   - Wait for that child to finish before spawning the child for the next file, so capture its final response against the matching file.
   - Parse the final response as exactly these two sections: `## Coding-standard descriptions` and `## Coding-standard references`.
   - Keep the findings from those sections separate; each finding belongs to the input file it was produced from.

4. Write these two Markdown reports, replacing any prior versions:

   - `sniffed-coding-standard-descriptions.md`
   - `sniffed-coding-standard-references.md`

   Each report starts with a level-one heading matching its filename's subject: `# Coding-standard descriptions` or `# Coding-standard references`. Include a level-two heading with the project-root-relative path in backticks only for a file that reported at least one finding in that report's corresponding agent section. Copy its findings below the heading. When no selected file reported a finding for a report, write `None found.` below its level-one heading. Preserve the confirmed file order among the included files in both reports.

5. Read both reports back. Verify that each contains a level-two section for every and only the confirmed files with findings in its matching detector section, in the displayed scope order. Report the two paths and the sniffed-file count.
