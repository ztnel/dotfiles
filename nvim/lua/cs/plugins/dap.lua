return {
    {
        "jay-babu/mason-nvim-dap.nvim",
        event = "VeryLazy",
        dependencies = {
            "williamboman/mason.nvim",
            "mfussenegger/nvim-dap",
        },
        opts = {
            ensure_installed = {
                "codelldb",
                "debugpy",
                "js-debug-adapter",
            },
            automatic_installation = true,
        },
    },
    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
        },
        keys = {
            { "<Leader>b", desc = "DAP toggle breakpoint" },
            { "<Leader>n", desc = "DAP step over" },
            { "<Leader>s", desc = "DAP step into" },
            { "<Leader>c", desc = "DAP continue" },
            { "<Leader>q", desc = "DAP terminate" },
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")
            local mason_path = vim.fn.stdpath("data") .. "/mason/packages"

            dapui.setup()

            dap.listeners.before.attach.dapui_config = function()
                dapui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated.dapui_config = function()
                dapui.close()
            end
            dap.listeners.before.event_exited.dapui_config = function()
                dapui.close()
            end

            vim.keymap.set("n", "<Leader>b", dap.toggle_breakpoint, {})
            vim.keymap.set("n", "<Leader>n", dap.step_over, {})
            vim.keymap.set("n", "<Leader>s", dap.step_into, {})
            vim.keymap.set("n", "<Leader>c", dap.continue, {})
            vim.keymap.set("n", "<Leader>q", dap.terminate, {})

            vim.fn.sign_define("DapBreakpoint", {
                text = "*",
                texthl = "DapBreakpoint",
                linehl = "DapBreakpoint",
                numhl = "DapBreakpoint",
            })

            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = {
                    command = mason_path .. "/codelldb/extension/adapter/codelldb",
                    args = { "--port", "${port}" },
                },
            }

            dap.adapters.python = {
                type = "executable",
                command = mason_path .. "/debugpy/venv/bin/python",
                args = { "-m", "debugpy.adapter" },
            }

            dap.adapters["pwa-node"] = {
                type = "server",
                host = "127.0.0.1",
                port = "${port}",
                executable = {
                    command = "node",
                    args = {
                        mason_path .. "/js-debug-adapter/js-debug/src/dapDebugServer.js",
                        "${port}",
                    },
                },
            }

            dap.configurations.c = {
                {
                    name = "Launch file",
                    type = "codelldb",
                    request = "launch",
                    program = function()
                        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
                    end,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                },
            }

            dap.configurations.cpp = dap.configurations.c

            dap.configurations.python = {
                {
                    name = "Launch file",
                    type = "python",
                    request = "launch",
                    program = "${file}",
                    console = "integratedTerminal",
                    cwd = "${workspaceFolder}",
                },
            }

            local js_configs = {
                {
                    name = "Launch current file",
                    type = "pwa-node",
                    request = "launch",
                    program = "${file}",
                    cwd = "${workspaceFolder}",
                    sourceMaps = true,
                },
                {
                    name = "Attach to process",
                    type = "pwa-node",
                    request = "attach",
                    processId = require("dap.utils").pick_process,
                    cwd = "${workspaceFolder}",
                },
            }

            dap.configurations.javascript = js_configs
            dap.configurations.typescript = js_configs
        end,
    },
}
