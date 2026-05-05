return {
    {
        "copilotlsp-nvim/copilot-lsp",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "neovim/nvim-lspconfig",
            "saghen/blink.cmp",
        },
        config = function()
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            local has_blink, blink = pcall(require, "blink.cmp")
            if has_blink then
                capabilities = blink.get_lsp_capabilities(capabilities)
            end

            vim.g.copilot_nes_debounce = 75

            require("copilot-lsp").setup({
                nes = {
                    move_count_threshold = 1,
                },
            })

            vim.lsp.config("copilot_ls", {
                capabilities = capabilities,
                root_markers = { ".git" },
            })

            vim.schedule(function()
                vim.lsp.enable("copilot", false)
                vim.lsp.enable("copilot_ls")
            end)
        end,
    },
}
