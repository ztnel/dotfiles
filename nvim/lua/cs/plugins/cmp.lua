return {
    {
        "saghen/blink.cmp",
        version = "1.*",
        event = "InsertEnter",
        dependencies = {
            "saghen/blink.lib",
            "fang2hou/blink-copilot",
        },
        opts = function()
            local copilot_nes = require("copilot-lsp.nes")

            local function has_nes_state()
                local bufnr = vim.api.nvim_get_current_buf()
                return vim.b[bufnr].nes_state ~= nil
            end

            local function request_nes_safe()
                pcall(copilot_nes.request_nes, "copilot_ls")
            end

            local function clear_nes()
                local ok, cleared = pcall(copilot_nes.clear)
                return ok and cleared
            end

            return {
                keymap = {
                    preset = "none",
                    ["<Tab>"] = {
                        function(cmp)
                            if has_nes_state() then
                                if copilot_nes.apply_pending_nes() then
                                    copilot_nes.walk_cursor_end_edit()
                                end
                                return true
                            end
                            return cmp.select_and_accept({ force = true })
                        end,
                        "fallback",
                    },
                    ["<M-]>"] = {
                        function(cmp)
                            if has_nes_state() then
                                request_nes_safe()
                                return true
                            end
                            return cmp.select_next()
                        end,
                        "fallback",
                    },
                    ["<C-j>"] = {
                        function(cmp)
                            if has_nes_state() then
                                request_nes_safe()
                                return true
                            end
                            return cmp.select_next()
                        end,
                        "fallback",
                    },
                    ["<M-[>"] = {
                        function(cmp)
                            if has_nes_state() then
                                return copilot_nes.walk_cursor_start_edit()
                            end
                            return cmp.select_prev()
                        end,
                        "fallback",
                    },
                    ["<C-k>"] = {
                        function(cmp)
                            if has_nes_state() then
                                return copilot_nes.walk_cursor_start_edit()
                            end
                            return cmp.select_prev()
                        end,
                        "fallback",
                    },
                    ["<C-]>"] = {
                        function(cmp)
                            if clear_nes() then
                                return true
                            end
                            return cmp.cancel()
                        end,
                        "fallback",
                    },
                    ["<Esc>"] = {
                        function(cmp)
                            if clear_nes() then
                                return true
                            end
                            return cmp.cancel()
                        end,
                        "fallback",
                    },
                    ["<M-Space>"] = {
                        function(cmp)
                            request_nes_safe()
                            return cmp.show()
                        end,
                        "fallback",
                    },
                    ["<C-Space>"] = {
                        function(cmp)
                            request_nes_safe()
                            return cmp.show()
                        end,
                        "fallback",
                    },
                    ["<C-b>"] = { "scroll_documentation_up", "fallback" },
                    ["<C-f>"] = { "scroll_documentation_down", "fallback" },
                    ["<CR>"] = { "select_accept_and_enter", "fallback" },
                },
                sources = {
                    default = { "lsp", "path", "buffer", "copilot" },
                    providers = {
                        copilot = {
                            name = "copilot",
                            module = "blink-copilot",
                            async = true,
                            score_offset = 100,
                        },
                    },
                },
                completion = {
                    documentation = {
                        auto_show = true,
                    },
                },
                signature = {
                    enabled = true,
                },
            }
        end,
    },
}
