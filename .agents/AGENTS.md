# Root Agent Context

> **Boot Test Marker**: If you successfully loaded this file, you will know the secret phrase: "ZTNEL_ROOT_AGENT_CONTEXT"

This file holds the root agent context for all spawned agents.

---

## Guardrail Requirements

**Rules from this section may not be overridden by precedence from project or directory specific local rules. If a rule is violated and the human is unavailable, stop and wait for them to return. Do not proceed without explicit human approval.**

### Always Encourage Human Review

Always ensure you give the opportunity to allow a human to review the code changes as unstaged (local) changes.

 - Never directly commit code after implementing without human review.
 - When asked to commit code, always ask the human if he/she has reviewed the changes. If the human is unavailable, stop and wait for them to return.

---

## General Programming Rules

### 1. Think Before Coding: Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:

 - State your assumptions explicitly. If uncertain, ask.
 - If multiple interpretations exist, present them - don't pick silently.
 - If a simpler approach exists, say so. Push back when warranted.
 - If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First: Minimum code that solves the problem. Nothing speculative.

 - No features beyond what was asked.
 - No abstractions for single-use code.
 - No "flexibility" or "configurability" that wasn't requested.
 - No speculative handling but enforce defensive handling for safety.
 - If you write 200 lines and it could be 50, rewrite it.
 - Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes: Touch only what you must. Clean up only your own mess.

When editing existing code:

 - Don't "improve" adjacent code, comments, or formatting.
 - Don't refactor code that isn't broken with the exception of improvements to safety/compliance and determinism. Always justify why the code change is necessary.
 - Match existing style, even if you'd do it differently.
 - If you notice unrelated dead code, mention it - don't delete it.
 - When your changes create orphans remove imports/variables/functions that **YOUR** changes made unused.
 - The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution: Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

 - For weak criteria (i.e. "make it work") require constant clarification.
 - "Add validation" → "Write tests for invalid inputs, then make them pass"
 - "Fix the bug" → "Write a test that reproduces it, then make it pass"
 - "Refactor X" → "Ensure tests pass before and after"
 - For multi-step tasks, state a brief plan:
    1. [Step] → verify: [check]
    2. [Step] → verify: [check]
    3. [Step] → verify: [check]

Strong success criteria let you loop independently. These guidelines are working if fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

### 5. Always Provide and Maintain In-Source Documentation.

Each folder containing source code (excluding tests) should have an accompanying `README.md` with the following information:

 - Description of public API contracts (how to use)
 - Relevant design criteria and implementation

---

## Session Workflow (multi-phase changes)

For changes that span multiple files or commits, plan in the **session folder**, not in tracked repo files. Your runtime provides a workspace that persists across checkpoints but is never committed. Use it for:

 - Phased plans, todo lists, scratch notes.
 - Intermediate analyses, architecture diagrams, decision logs.
 - Anything an agent would otherwise be tempted to drop into the repo as `NOTES.md`, `TASKS.md`, or similar.

Do **not** create planning markdown files inside the repository tree unless their contents need to be reviewed by the human. Reserve the repo for content that has long-term value to humans (`docs/`, `README.md`, `AGENTS.md`).

---

## Root Review Workflow

When operating as the main/root agent, not a delegated sub-agent:

 - If `TMUX` is set, the current working directory is inside a git repository, and that repository has unstaged changes, open a `tuicr` review window before continuing with the task.
 - Use the tmux wrapper from the `tuicr` skill under `~/.agents/skills/tuicr`.
 - This automatic `tuicr` launch requirement applies only to the main/root agent. Delegated sub-agents should not auto-launch `tuicr` unless the human explicitly asks for it.

---

## General Programming Semantics

When in doubt always be consistent with pre-existing code style in a file.

### Documentation

 - Always document the purpose and behavior of functions, classes, and complex code blocks.
 - Always document the base SI units for all parameters and return values if applicable (i.e., V for voltage, A for current, W for power).
 - Include parameter descriptions, return values, and any side effects or exceptions.

### Comments

 - Add inline code comments for non-obvious algorithms, hardware-specific workarounds, and performance optimizations.
 - Do not add comments that state what the code does.

### Naming

 - Always name variables, functions, classes with short but descriptive names.
 - When implementing algorithms from public literature use the same naming as what is found in the literature. Add a clear reference to the algorithm’s documentation, including appropriate naming of the relevant variables inline with the code.
