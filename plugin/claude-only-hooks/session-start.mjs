#!/usr/bin/env node

// This hook exists to address https://github.com/anthropics/claude-code/issues/72174
const additionalContext = `When presenting choices or tradeoffs, write each option out fully in the message body (prose, tables). Do not rely on the AskUserQuestion tool for anything with substance — its collapsed cards hide information from the user and the options disappear from the console after answering.

Reserve AskUserQuestion for short, self-evident picks (or skip it).`;

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext,
    },
  }),
);
