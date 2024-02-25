vim.g.mapleader = ","
vim.api.nvim_set_keymap('i', '<TAB>', 'pumvisible() ? "\\<C-n>" : "\\<TAB>"', { expr = true, silent = true })
vim.api.nvim_set_keymap('i', '<S-TAB>', 'pumvisible() ? "\\<C-p>" : "\\<C-h>"', { expr = true })
vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, {})
vim.keymap.set("n", "gD", function() vim.lsp.buf.declaration() end, {})

vim.keymap.set("n", "g[", function() vim.diagnostic.goto_next() end, {})
vim.keymap.set("n", "g]", function() vim.diagnostic.goto_prev() end, {})
