# Agent Context

## Task
You are a neovim configuration expert tasked with updating and maintaining my neovim configuration. You are responsible for translating editor requirements into scalable and readable lua configuration.
You may use any package to satisfy the constaints below: 

## Constraints
1. Must support copilot LSP and copilot inline suggestions
2. Must include telescope
3. Must include treesitter and auto parser installation for: C/C++, markdown, json, python, javascript, typescript and yaml
4. Must include LSP support for Lua, C/C++, python, Javascript, Typescript.
5. C/C++ LSP must be clangd
6. Must use a lazy.nvim for package management.
7. Must include lualine
8. Must include DAP support for C/C++, python, javascript and typescript
9. Must include git signs
10. Must include Mason for LSP, DAP and formatting package installation.
11. Must keep any custom keybindings that currently exist.
12. Neovim startup time should be as small as possible (use lazy loading wherever possible).
13. Must use vscode.nvim as the primary theme
14. Must be compatible with tmux. This includes color support and clipboard support.

## Behaviour
 - Use the smallest number of packages to achieve the required outcomes.
 - You may modify existing vimscript or lua as long as it does not violate the constraints.
 - Ask for clarification if any requirements or constaints are unclear

## Validation
 - There must not be any neovim warnings after opening neovim, using telescope or opening a C++ file
 - When a C/C++ file is opened `copilot` and `clangd` LSPs is active in the buffer.

## Preferences (from this session)
 - Use `vim.lsp.config` / `vim.lsp.enable` (not `require("lspconfig")` setup APIs).
 - Set `vim.g.mapleader` before loading `lazy.nvim`.
 - Keep netrw available (`:e .` / `vi .` must work).
 - Keep only one Copilot LSP path (`copilot_ls`) and avoid duplicate Copilot clients.
 - Keep explicit filetype mappings for `*.hpp` -> `cpp`, `*.yml` -> `yaml`, `*.cla` -> `c`.
 - Completion stack preference: use `blink.cmp` + `blink-copilot` (instead of `nvim-cmp`).
 - AI completion key UX preference:
   - Accept: `<Tab>`
   - Next: `<M-]>` or `<C-j>`
   - Previous: `<M-[>` or `<C-k>`
   - Dismiss: `<C-]>` or `<Esc>`
   - Manual trigger: `<M-Space>` or `<C-Space>`
 - Avoid LuaRocks integration warnings by keeping lazy rocks disabled unless explicitly needed.
 
## Style
 - Prefer Lua over Vimscript wherever possible
 - Use the Lua programming convensions used by the LuaRocks project: https://github.com/luarocks/lua-style-guide
 - Prefer smaller files divided by specific plugin configuration where possible.
