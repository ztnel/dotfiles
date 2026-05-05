local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    { import = "cs.plugins.ui" },
    { import = "cs.plugins.telescope" },
    { import = "cs.plugins.treesitter" },
    { import = "cs.plugins.git" },
    { import = "cs.plugins.cmp" },
    { import = "cs.plugins.lsp" },
    { import = "cs.plugins.copilot" },
    { import = "cs.plugins.dap" },
}, {
    defaults = {
        lazy = true,
    },
    install = {
        colorscheme = { "vscode" },
    },
    rocks = {
        enabled = false,
    },
    checker = {
        enabled = false,
    },
    change_detection = {
        notify = false,
    },
    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "matchit",
                "matchparen",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})
