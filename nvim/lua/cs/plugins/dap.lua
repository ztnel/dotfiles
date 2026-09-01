return {
    {
        "mfussenegger/nvim-dap",
        cmd = {
            "DapContinue",
            "DapToggleBreakpoint",
            "DapStepOver",
            "DapStepInto",
            "DapStepOut",
            "DapTerminate",
        },
        keys = {
            { "<F5>", desc = "DAP continue" },
            { "<F9>", desc = "DAP toggle breakpoint" },
            { "<F10>", desc = "DAP step over" },
            { "<F11>", desc = "DAP step into" },
            { "<S-F11>", desc = "DAP step out" },
            { "<Leader>b", desc = "DAP toggle breakpoint" },
            { "<Leader>n", desc = "DAP step over" },
            { "<Leader>s", desc = "DAP step into" },
            { "<Leader>c", desc = "DAP continue" },
            { "<Leader>o", desc = "DAP step out" },
            { "<Leader>q", desc = "DAP terminate" },
        },
        dependencies = {
            "williamboman/mason.nvim",
            "rcarriga/nvim-dap-ui",
        },
        config = function()
            local dap = require("dap")
            local mason_path = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages")
            local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

            local function python_venv_python(root)
                local suffix = is_windows and { "Scripts", "python.exe" } or { "bin", "python" }
                return vim.fs.joinpath(root, suffix[1], suffix[2])
            end

            local function resolve_python_path()
                if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
                    return python_venv_python(vim.env.VIRTUAL_ENV)
                end

                local venv = vim.fs.find({ ".venv", "venv" }, {
                    upward = true,
                    path = vim.fn.getcwd(),
                    type = "directory",
                })[1]

                if venv then
                    return python_venv_python(venv)
                end

                return is_windows and "python" or "python3"
            end

            local function debugpy_python()
                if is_windows then
                    return vim.fs.joinpath(mason_path, "debugpy", "venv", "Scripts", "python.exe")
                end

                return vim.fs.joinpath(mason_path, "debugpy", "venv", "bin", "python")
            end

            vim.keymap.set("n", "<Leader>b", dap.toggle_breakpoint, {})
            vim.keymap.set("n", "<Leader>n", dap.step_over, {})
            vim.keymap.set("n", "<Leader>s", dap.step_into, {})
            vim.keymap.set("n", "<Leader>o", dap.step_out, {})
            vim.keymap.set("n", "<Leader>c", dap.continue, {})
            vim.keymap.set("n", "<Leader>q", dap.terminate, {})
            vim.keymap.set("n", "<F5>", dap.continue, {})
            vim.keymap.set("n", "<F9>", dap.toggle_breakpoint, {})
            vim.keymap.set("n", "<F10>", dap.step_over, {})
            vim.keymap.set("n", "<F11>", dap.step_into, {})
            vim.keymap.set("n", "<S-F11>", dap.step_out, {})

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
                command = debugpy_python(),
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
                    pythonPath = resolve_python_path,
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
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

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
        end,
    },
}
