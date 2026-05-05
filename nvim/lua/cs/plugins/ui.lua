return {
    {
        "Mofiqul/vscode.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("vscode").setup({
                underline_links = true,
                italic_inlayhints = true,
                terminal_colors = true,
            })

            vim.cmd.colorscheme("vscode")
        end,
    },
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true,
    },
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        opts = {
            options = {
                theme = "vscode",
            },
        },
    },
}
