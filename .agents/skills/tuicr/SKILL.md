---
name: tuicr
description: Use tuicr's review CLI to read and add comments in active TUI review sessions, and launch tuicr in tmux when a user needs an interactive review pane.
---

# tuicr Review Workflow

Use `tuicr review` as the default agent interface. The TUI is where the human
reviews code; the CLI is how the agent discovers active sessions, reads user
comments, and, only when appropriate, adds agent-authored comments.

## Core Rule

First decide which workflow the user is asking for:

1. **User-led review of agent-generated changes**
   - The user wants to inspect the patch and write comments in tuicr.
   - Your job is to open or find the session, then retrieve the user's comments
     with `tuicr review comments` when they say comments are ready. If you are
     explicitly waiting while the user reviews, poll the same command
     periodically and look for new comment IDs.
   - Do not add your own review comments, do not preemptively review your own
     patch, and do not impersonate the user's comments.

2. **Agent review of a patch**
   - The user wants you to understand, critique, or summarize a patch.
   - You may inspect the patch and propose findings.
   - If you can confidently identify this workflow and the target session, add
     findings directly with `tuicr review add` and an explicit `--username`
     passing the agent model ID. Ask first when the workflow or session is ambiguous.

If the user's intent is ambiguous, ask which workflow they want.

## Attach To A Session

1. Determine the repository directory from the user's request, current working
   directory, or recent file operations. Ask if it is ambiguous.

2. List persisted sessions:

   ```bash
   tuicr review list --repo /path/to/repo
   ```

3. Choose the session:
   - If the CLI clearly reports exactly one relevant active session with
     `"active": true`, attach to it.
   - If multiple sessions are active, or the correct session is not clear, ask
     the user which slug to use.
   - If the user provided a slug or session JSON path, use it directly.
   - If there is no active session, start or wait for one as described below.
   - Until active-session discovery is formalized as a stable protocol, treat
     `"active": true` as a convenience signal. If slug resolution fails, ask the
     user for the slug or repo path used by the session.

The CLI works even if the agent is not running inside tmux, so do not require
another multiplexer just to connect to an existing active session.

## Start A Session

When the user needs an interactive tuicr pane and no active session exists:

| Environment | Action |
|-------------|--------|
| `$TMUX` is set | Run `tuicr-wrapper.sh /path/to/repo` |
| Neither is set | Tell the user you are waiting for them to start `tuicr` in the repo, then attach with `tuicr review list` after they say it is ready |

Wrapper paths are relative to this skill directory:

```bash
<skill-directory>/tuicr-wrapper.sh /path/to/repo
```

If your tool can launch background processes, start the wrapper detached from
the current Copilot session so it can keep watching for new human comments
while the agent continues working. Do not keep the main agent blocked on the
wrapper process when detached mode is available.

If your tool supports command timeouts, use a long timeout, such as 10 minutes,
because the wrapper waits for the TUI to exit. Once the TUI creates its active
session, use `tuicr review list --repo /path/to/repo` to capture the slug. If
your environment cannot run another command while the wrapper is waiting, read
the comments after the user exits tuicr.

The tmux wrapper must start a live watch loop for every review session it
launches. That watcher should identify human comments by missing `username`
metadata and should ignore agent-authored comments that do carry agent
identity. If the flattened `tuicr review comments` output does not expose that
metadata, the watcher should fall back to the persisted session JSON where the
author data is available. When new human comment IDs appear, the wrapper should
wake the originating agent pane with both `tmux display-message` and `tmux
send-keys` so the agent is nudged to read the session again. `focus-events on`
improves `send-keys` reliability for this workflow. Working-tree
reviews use the tmux window name `tuicr-unstaged`; explicit revset-only reviews
use `tuicr-<base...head>`. Working-tree
reviews use the tmux window name `tuicr-unstaged`; explicit revset-only reviews
use `tuicr-<base...head>`.

## Read User Comments

This is the main review loop for user-led review.

There is no native push stream from tuicr to the agent. Read comments by
running the CLI on demand. After the user says comments are ready, after the
tmux wrapper wakes you for new comments, or after the TUI exits, run:

```bash
tuicr review comments --repo /path/to/repo --session <slug>
```

The command emits JSON. Each comment includes fields like:

- `id`
- `location`
- `path`
- `start_line`
- `end_line`
- `side`
- `comment_type`
- `lifecycle_state`
- `username` when available
- `content`

Treat these comments as the user's review feedback:

- Missing or empty `username`: human-authored comment
- Present `username`: agent-authored comment
- In persisted local session files, the same distinction may appear as
  `author: "user"` for humans and a model name for agent-authored comments

- `issue`: blocking problem to fix first
- `suggestion`: consider implementing or explain why not
- `note`: answer or acknowledge
- `praise`: no action required

When a human comment requests a change, reply in tuicr before implementing the
change. Use a `reply` comment on the same file, side, start line, and end line
so the conversation stays attached to the original review context. If the human
comment spans a range, your reply must use the exact same range with both
`--line` and `--end-line`.

Use this reply structure for the first reply on every change request:

```text
<verdict> - <brief reason for the verdict>

<current state such as waiting for human feedback, queued, dispatched to subagent, in progress, or completed>
```

Guidance:

- `agree`: the request is valid and you intend to make the change
- `disagree`: the request should not be applied; explain why
- `needs clarification`: the request is ambiguous or conflicts with other constraints
- The first line should combine the verdict and justification in the format
  `<verdict> - <brief reason>`.
- Keep the justification brief and specific to the request
- Keep the status current as work progresses; if you are blocked on the human,
  say so explicitly
- After the first reply, subsequent replies should report only the delta. If
  only the status changed, a short update such as `done` is preferred over
  repeating the earlier verdict and justification.

If you are waiting during an active review without the tmux live watch, poll
this command about every 30 seconds and compare comment IDs with the previous
result. Read immediately when the user says comments are ready. Stop polling
once the user says the review is done or your tooling would block other work.

If the result is empty, ask whether the user saved comments in the intended
session or whether another active session should be selected. If the review may
have continued while you were working, rerun `tuicr review comments` before
claiming completion.

## Add Agent Comments

Only add comments when the workflow allows it and, for agent-authored review,
after the user approves writing them into tuicr.

Defaults:

- Prefer line comments when a specific file and line are known.
- Use file comments for file-scoped feedback.
- Use review-level comments only for whole-review summaries.
- Use `--type issue` for problems by default.
- Use `suggestion`, `note`, or `praise` when that better matches the intent.
- Always pass the current agent model ID to `--username` on every agent-authored
  comment.
- Use `--type reply` for agent replies in a human/agent back-and-forth thread.
- For replies, post on the exact same file, side, start line, and end line as
  the comment you are answering so tuicr keeps the thread in sequential order.
- For single-line comments, use only `--line`. For range comments, use both
  `--line` and `--end-line`, and make them exactly equal to the human comment's
  `start_line` and `end_line`.
- For human change requests, the first reply must include verdict,
  justification, and status in that order before you implement or reject the
  request.
- After that first reply, send only incremental follow-up updates rather than
  repeating the full structure.

Use replies to keep the conversation anchored to one block of text. When a
human asks a follow-up question or challenges a proposed fix on a specific
line, answer with a `reply` comment at that exact location instead of opening a
new top-level comment elsewhere.

Examples:

```bash
tuicr review add --repo /path/to/repo --session <slug> \
  --target-file src/main.rs \
  --line 42 \
  --side new \
  --type issue \
  --username "gpt-5.3-codex" \
  "Handle the empty case here."
```

## Multiplexer Tips

tmux:

- Switch panes: `Ctrl-b` then arrow keys
- Close tuicr: press `q`
- Resize panes: `Ctrl-b` then `Ctrl-arrow`
- Zoom pane: `Ctrl-b` then `z`

## Error Handling

| Situation | Action |
|-----------|--------|
| Multiple plausible active sessions | Ask which session slug to use |
| No active session, tmux available | Start a new tuicr pane with the wrapper |
| No active session, no tmux | Tell the user you are waiting for them to start `tuicr` |
| `tuicr` not installed | Tell the user to install tuicr |
| Not a repository | Ask for the correct repo directory |
| Comments are empty | Confirm the selected session or ask the user to save/add comments |

## When Not To Use

- The user only wants raw `git diff` output.
- The user explicitly asks for a non-tuicr review workflow.
- The task is remote PR review and no tuicr PR session is involved.
