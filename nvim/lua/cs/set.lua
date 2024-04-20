vim.opt.number = true
vim.opt.cursorline = true
vim.opt.showmatch = true
vim.opt.ttyfast = true
vim.opt.ignorecase = true
vim.opt.clipboard = 'unnamedplus'
vim.opt.relativenumber = true
vim.opt.wrap = false
vim.opt.expandtab = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.termguicolors = true
vim.opt.wildignore = {'*/cache/*', '*/tmp/*'}
vim.opt.modeline = false

vim.cmd.colorscheme "vscode"

local c = require('vscode.colors').get_colors()

require('vscode').setup({
    -- Alternatively set style in setup
    -- Enable transparent background
    transparent = true,
    -- Underline `@markup.link.*` variants
    underline_links = true,
})
