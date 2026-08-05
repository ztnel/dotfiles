# Dotfiles Repo Guidance

## Purpose
This repository stores my cross-platform dotfiles for macOS, Windows, and Linux. Keep changes portable, minimal, and easy to review.

## Scope
These instructions apply to the repository root and should be followed for any new files or edits here. If a subdirectory has its own `AGENTS.md`, follow that file for work in that subtree.

## Working rules
- Prefer small, surgical changes over broad refactors.
- Preserve existing behavior unless the user explicitly asks for a change.
- Keep platform-specific logic isolated to the files or directories that need it.
- Avoid adding new dependencies or tooling unless they are required for the task.
- When changing config for an app, keep existing keybindings, aliases, and user-facing shortcuts unless the task says otherwise.

## Repo conventions
- Treat shell, editor, and terminal configs as user-facing and portable.
- Favor clear defaults that work across macOS, Windows, and Linux.
- Keep Neovim changes in the `nvim/` subtree and tmux changes in `.tmux.conf`.
- Keep shell changes in `.zshrc` or the relevant shell config file.

## Verification
- If a change affects a nested area, read that area's local instructions before editing.
