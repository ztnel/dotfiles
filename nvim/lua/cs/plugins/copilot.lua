local function ensure_tokenizer(name)
    local package_root = vim.fs.joinpath(
        vim.fn.stdpath("data"),
        "mason",
        "packages",
        "copilot-language-server",
        "node_modules",
        "@github",
        "copilot-language-server"
    )
    local resource = vim.fs.joinpath(package_root, "dist", "resources", name .. ".tiktoken.noindex")
    local target = vim.fs.joinpath(package_root, "dist", name .. ".tiktoken")

    -- copilot-language-server expects tokenizer files at dist/*.tiktoken,
    -- but Mason installs them under dist/resources with a .noindex suffix.
    if vim.uv.fs_stat(target) or not vim.uv.fs_stat(resource) then
        return
    end

    local ok, data = pcall(vim.fn.readfile, resource, "b")
    if ok and data then
        pcall(vim.fn.writefile, data, target, "b")
    end
end

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
            ensure_tokenizer("cl100k_base")
            ensure_tokenizer("o200k_base")

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
