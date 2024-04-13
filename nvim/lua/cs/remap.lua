vim.g.mapleader = " "
vim.api.nvim_set_keymap('i', '<TAB>', 'pumvisible() ? "\\<C-n>" : "\\<TAB>"', { expr = true, silent = true })
vim.api.nvim_set_keymap('i', '<S-TAB>', 'pumvisible() ? "\\<C-p>" : "\\<C-h>"', { expr = true })
