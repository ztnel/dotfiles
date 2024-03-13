vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, {})
vim.keymap.set("n", "gD", function() vim.lsp.buf.declaration() end, {})
vim.keymap.set("n", "g[", function() vim.diagnostic.goto_next() end, {})
vim.keymap.set("n", "g]", function() vim.diagnostic.goto_prev() end, {})
