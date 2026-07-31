---
name: brainstorming
description: 'Adaptation of brainstorming skill originally from Jesse Vincent. Some differences: Works in whatever branch, is user invoked, has peer review, spec/plan location is fixed (and different)'
disable-model-invocation: true
---

# Brainstorming Ideas Into Designs

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

If the current repository has folder /docs/adr then include the skill "domain-modeling" with this session.

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function utility, a config change — all of them. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for truly simple projects), but you MUST present it and get approval.

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Explore project context** — check files, docs, recent commits
2. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
3. **Propose 2-3 approaches** — with trade-offs and your recommendation
4. **Present design** — in sections scaled to their complexity, get user approval after each section
5. **Write design doc** — save to `docs/honist-v/specs/YYYY-MM-DD-<topic>-design.md` and commit
6. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
7. **Peer review** — use prompt-a-peer-high to review the committed spec, fix clear issues
8. **User reviews written spec** — ask user to review the spec file before proceeding
9. **Transition to implementation** — invoke writing-plans skill to create implementation plan

## Process Flow

```dot
digraph brainstorming {
    "Explore project context" [shape=box];
    "Ask clarifying questions" [shape=box];
    "Propose 2-3 approaches" [shape=box];
    "Present design sections" [shape=box];
    "User approves design?" [shape=diamond];
    "Write design doc" [shape=box];
    "Spec self-review\n(fix + commit inline)" [shape=box];
    "Peer reviews spec" [shape=box];
    "Clear issues?" [shape=diamond];
    "Certain fix?" [shape=diamond];
    "Propose 2-3 fixes" [shape=box];
    "Substantial changes?" [shape=diamond];
    "User reviews spec?" [shape=diamond];
    "Invoke writing-plans skill" [shape=doublecircle];

    "Explore project context" -> "Ask clarifying questions";
    "Ask clarifying questions" -> "Propose 2-3 approaches";
    "Propose 2-3 approaches" -> "Present design sections";
    "Present design sections" -> "User approves design?";
    "User approves design?" -> "Present design sections" [label="no, revise"];
    "User approves design?" -> "Write design doc" [label="yes"];
    "Write design doc" -> "Spec self-review\n(fix + commit inline)";
    "Spec self-review\n(fix + commit inline)" -> "Peer reviews spec";
    "Peer reviews spec" -> "Clear issues?";
    "Clear issues?" -> "User reviews spec?" [label="no\n(report discarded feedback)"];
    "Clear issues?" -> "Certain fix?" [label="yes"];
    "Certain fix?" -> "Substantial changes?" [label="yes, fix + commit inline"];
    "Certain fix?" -> "Propose 2-3 fixes" [label="no"];
    "Propose 2-3 fixes" -> "Substantial changes?";
    "Substantial changes?" -> "Spec self-review\n(fix + commit inline)" [label="yes"];
    "Substantial changes?" -> "User reviews spec?" [label="no"];
    "User reviews spec?" -> "Spec self-review\n(fix + commit inline)" [label="changes requested"];
    "User reviews spec?" -> "Invoke writing-plans skill" [label="approved"];
}
```

**The terminal state is invoking writing-plans.** Do NOT invoke frontend-design, mcp-builder, or any other implementation skill. The ONLY skill you invoke after brainstorming is writing-plans.

## The Process

**Understanding the idea:**

- Check out the current project state first (files, docs, recent commits)
- Before asking detailed questions, assess scope: if the request describes multiple independent subsystems (e.g., "build a platform with chat, file storage, billing, and analytics"), flag this immediately. Don't spend questions refining details of a project that needs to be decomposed first.
- If the project is too large for a single spec, help the user decompose into sub-projects: what are the independent pieces, how do they relate, what order should they be built? Then brainstorm the first sub-project through the normal design flow. Each sub-project gets its own spec → plan → implementation cycle.
- For appropriately-scoped projects, ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria
- If a key claim is cheaply testable then test it first.

**Exploring approaches:**

- Propose 2-3 different approaches with their trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why
- Always indicate the tradeoffs of each approach. If there is no differentiation in the tradeoffs its not a useful question.

**Presenting the design:**

- Once you believe you understand what you're building, present the design
- Scale each section to its complexity: a few sentences if straightforward, up to 200-300 words if nuanced
- Ask after each section whether it looks right so far
- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

**Design for isolation and clarity:**

- Break the system into smaller units that each have one clear purpose, communicate through well-defined interfaces, and can be understood and tested independently
- For each unit, you should be able to answer: what does it do, how do you use it, and what does it depend on?
- Can someone understand what a unit does without reading its internals? Can you change the internals without breaking consumers? If not, the boundaries need work.
- Smaller, well-bounded units are also easier for you to work with - you reason better about code you can hold in context at once, and your edits are more reliable when files are focused. When a file grows large, that's often a signal that it's doing too much.

**Working in existing codebases:**

- Explore the current structure before proposing changes. Follow existing patterns.
- Where existing code has problems that affect the work (e.g., a file that's grown too large, unclear boundaries, tangled responsibilities), include targeted improvements as part of the design - the way a good developer improves code they're working in.
- Don't propose unrelated refactoring. Stay focused on what serves the current goal.

## After the Design

**Documentation:**

- Write the validated design (spec) to `docs/honist-v/specs/YYYY-MM-DD-<topic>-design.md`
- Commit the design document to git

**Spec Self-Review:** After writing the spec document, look at it with fresh eyes:

1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections, or vague requirements? Fix them.
2. **Internal consistency:** Do any sections contradict each other? Does the architecture match the feature descriptions?
3. **Scope check:** Is this focused enough for a single implementation plan, or does it need decomposition?
4. **Ambiguity check:** Could any requirement be interpreted two different ways? If so, pick one and make it explicit.

Fix any issues inline. No need to re-review — just commit the fixes and move on.

**Peer Review:** After the spec self-review passes and changes have been committed, use the **prompt-a-peer-high** skill to have a peer review the committed spec. If a peer reviewed an earlier version of the spec, ask it to review the changes since.

- For feedback that points to a clear issue with a certain fix go ahead and commit the fix inline.
- Tell the user about feedback that did not indicate a clear issue and is being discarded.
- Go to **Propose 2-3 fixes** to explore fixes for clear issues without a certain fix, otherwise skip to **User Review Gate**.

**Propose 2-3 fixes** For each clear issue without a certain fix:

- Propose 2-3 different fixes with their trade-offs.
- Present options conversationally with your recommendation and reasoning.
- Lead with your recommended option and explain why.
- Always indicate the tradeoffs of each approach. If there is no differentiation in the tradeoffs then also explain why the solution to the fix is uncertain.

Fix and commit issues inline. If there were substantial changes made return to **Spec Self-Review** otherwise continue to **User Review Gate**.

**User Review Gate:** After the spec review loop passes, ask the user to review the written spec before proceeding:

> "Spec written and committed to `<path>`. Please review it and let me know if you want to make any changes before we start writing out the implementation plan."

Wait for the user's response. If they request changes, make them and return to **Spec Self-Review**. Only proceed once the user approves.

**Implementation:**

- Invoke the writing-plans skill to create a detailed implementation plan
- Do NOT invoke any other skill. writing-plans is the next step.

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design, get approval before moving on
- **Be flexible** - Go back and clarify when something doesn't make sense
