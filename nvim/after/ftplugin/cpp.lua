local set = vim.opt
set.tabstop = 2
set.softtabstop = 2
set.shiftwidth = 2
set.expandtab = true

vim.api.nvim_set_hl(0, '@keyword.directive.cpp', { link = '@define' })
vim.api.nvim_set_hl(0, '@keyword.directive.define.cpp', { link = '@define' })
