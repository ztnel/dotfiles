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
vim.opt.fileformats = { "unix", "dos" }
vim.opt.fixeol = false
vim.opt.fixendofline = false
vim.o.tabstop = 4 -- A TAB character looks like 4 spaces
vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = 4 -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = 4 -- Number of spaces inserted when indenting

if vim.env.TMUX then
    vim.g.clipboard = {
        name = "tmux-clipboard",
        copy = {
            ["+"] = { "tmux", "load-buffer", "-w", "-" },
            ["*"] = { "tmux", "load-buffer", "-w", "-" },
        },
        paste = {
            ["+"] = { "tmux", "save-buffer", "-" },
            ["*"] = { "tmux", "save-buffer", "-" },
        },
        cache_enabled = 0,
    }
end
