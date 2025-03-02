require("dapui").setup()
local dap = require("dap")
local dapui = require("dapui")

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

vim.fn.sign_define(
    "DapBreakpoint",
    { text = "⏺", texthl = "DapBreakpoint", linehl = "DapBreakpoint", numhl = "DapBreakpoint" }
)

dap.adapters.delve = function(callback, config)
    if config.mode == 'remote' and config.request == 'attach' then
        callback({
            type = 'server',
            host = config.host or '127.0.0.1',
            port = config.port or '38697'
        })
    else
        callback({
            type = 'server',
            port = '${port}',
            executable = {
                command = 'dlv',
                args = { 'dap', '-l', '127.0.0.1:${port}', '--log', '--log-output=dap' },
                detached = vim.fn.has("win32") == 0,
            }
        })
    end
end


-- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
dap.configurations.go = {
    {
        type = "delve",
        name = "Debug",
        request = "launch",
        program = "${file}"
    },
    {
        type = "delve",
        name = "Debug test", -- configuration for debugging test files
        request = "launch",
        mode = "test",
        program = "${file}"
    },
    -- works with go.mod packages and sub packages 
    {
        type = "delve",
        name = "Debug test (go.mod)",
        request = "launch",
        mode = "test",
        program = "./${relativeFileDirname}"
    } 
}
