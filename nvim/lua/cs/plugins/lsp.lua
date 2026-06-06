local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

local function capabilities()
    local caps = vim.lsp.protocol.make_client_capabilities()
    local ok, blink = pcall(require, "blink.cmp")
    if ok then
        return blink.get_lsp_capabilities(caps)
    end

    return caps
end

local function setup_lsp()
    local lsp_capabilities = capabilities()

    vim.lsp.config("lua_ls", {
        capabilities = lsp_capabilities,
        cmd = { mason_bin .. "lua-language-server" },
        filetypes = { "lua" },
        root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    })

    vim.lsp.config("clangd", {
        capabilities = lsp_capabilities,
        cmd = {
            mason_bin .. "clangd",
            "--offset-encoding=utf-16",
            "--inlay-hints=true",
        },
        filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
        root_markers = {
            ".clangd",
            ".clang-tidy",
            ".clang-format",
            "compile_commands.json",
            "compile_flags.txt",
            ".git",
        },
        single_file_support = true,
    })

    vim.lsp.config("pyright", {
        capabilities = lsp_capabilities,
        cmd = { mason_bin .. "pyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
        single_file_support = true,
    })

    vim.lsp.config("ts_ls", {
        capabilities = lsp_capabilities,
        cmd = { mason_bin .. "typescript-language-server", "--stdio" },
        filetypes = {
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "javascript.jsx",
            "typescript.tsx",
        },
        root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
        single_file_support = true,
    })

    vim.lsp.config("gopls", {
        capabilities = lsp_capabilities,
        cmd = { mason_bin .. "gopls" },
        filetypes = { "go", "gomod", "gowork", "gotmpl" },
        root_markers = { "go.work", "go.mod", ".git" },
        single_file_support = true,
    })

    vim.lsp.enable("lua_ls")
    vim.lsp.enable("clangd")
    vim.lsp.enable("pyright")
    vim.lsp.enable("ts_ls")
    vim.lsp.enable("gopls")

    vim.keymap.set("n", "<Leader>e", vim.diagnostic.open_float)
    vim.keymap.set("n", "[d", function()
        vim.diagnostic.jump({ count = -1, float = true })
    end)
    vim.keymap.set("n", "]d", function()
        vim.diagnostic.jump({ count = 1, float = true })
    end)
    vim.keymap.set("n", "<Leader>q", vim.diagnostic.setloclist)

    vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
            vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })

            local opts = { buffer = ev.buf }
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
            vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
            vim.keymap.set("n", "<Leader>wa", vim.lsp.buf.add_workspace_folder, opts)
            vim.keymap.set("n", "<Leader>wr", vim.lsp.buf.remove_workspace_folder, opts)
            vim.keymap.set("n", "<Leader>wl", function()
                print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end, opts)
            vim.keymap.set("n", "<Leader>D", vim.lsp.buf.type_definition, opts)
            vim.keymap.set("n", "<Leader>rn", vim.lsp.buf.rename, opts)
            vim.keymap.set({ "n", "v" }, "<Leader>ca", vim.lsp.buf.code_action, opts)
            vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
            vim.keymap.set("n", "<Leader>f", function()
                vim.lsp.buf.format({ async = true })
            end, opts)
        end,
    })

    vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        update_in_insert = true,
        severity_sort = true,
    })
end

setup_lsp()

return {
    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        opts = {},
    },
    {
        "williamboman/mason-lspconfig.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
        },
        opts = {
            ensure_installed = {
                "lua_ls",
                "clangd",
                "pyright",
                "ts_ls",
                "gopls",
                "copilot",
            },
            automatic_installation = true,
            automatic_enable = false,
        },
    },
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        event = "VeryLazy",
        dependencies = {
            "williamboman/mason.nvim",
        },
        opts = {
            ensure_installed = {
                "stylua",
                "clang-format",
                "black",
                "prettier",
            },
        },
    },
}
