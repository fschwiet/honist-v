---
name: executing-plans
description: 'Adaptation of executing-plans skill originally from Jesse Vincent. Some differences: Works in whatever branch, is user invoked'
disable-model-invocation: true
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "We're using the executing-plans skill to implement this plan."

## The Process

### Step 1: Load and Review Plan

1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create todos for the plan items and proceed

### Step 2: Execute Tasks

Before the first task, record the starting commit: `git rev-parse HEAD`. This is the fixed point for Step 3.

For each task:

1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

### Step 3: Review the Changes

Invoke the `code-review-of-changeset` skill by name, passing the commit recorded in Step 2 as the fixed point.

Address every finding: fix it, or record why you're deferring it. Re-run any verification a fix touches.

### Step 4: Complete Development

After all tasks complete, verified, and reviewed:

- Announce: "We've completed and verified all tasks."

## When to Stop and Ask for Help

**STOP executing immediately when:**

- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

**Don't force through blockers** - stop and ask.

## When to Revisit Earlier Steps

**Re-review the plan if it changes** Return to Review (Step 1) when partner updates the plan based on your feedback**

## Remember

- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
