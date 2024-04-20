local set = vim.opt
set.tabstop = 2
set.softtabstop = 2
set.shiftwidth = 2
set.expandtab = true
-- c color theme mods
-- grey out disabled macro blocks
vim.api.nvim_set_hl(0, '@lsp.type.comment.c', { fg = '#51504F', bg = 'NONE' })
-- modify directive keywords
vim.api.nvim_set_hl(0, '@keyword.directive.c', { link = '@define' })
vim.api.nvim_set_hl(0, '@keyword.directive.define.c', { link = '@define' })
