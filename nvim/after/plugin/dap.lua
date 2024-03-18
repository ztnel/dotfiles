local dap, dapui = require("dap"), require("dapui")

dapui.setup(
{
    controls = {
        element = "repl",
        enabled = true,
        icons = {
            disconnect = "",
            pause = "",
            play = "",
            run_last = "",
            step_back = "",
            step_into = "",
            step_out = "",
            step_over = "",
            terminate = ""
        }
    },
    element_mappings = {},
    expand_lines = true,
    floating = {
        border = "single",
        mappings = {
            close = { "q", "<Esc>" }
        }
    },
    force_buffers = true,
    icons = {
        collapsed = "",
        current_frame = "",
        expanded = ""
    },
    layouts = { {
        elements = { {
            id = "scopes",
            size = 0.25
        }, {
            id = "breakpoints",
            size = 0.25
        }, {
            id = "stacks",
            size = 0.25
        }, {
            id = "watches",
            size = 0.25
        } },
        position = "left",
        size = 40
    }, {
        elements = { {
            id = "repl",
            size = 1.0
        }},
        position = "bottom",
        size = 10
    } },
    mappings = {
        edit = "e",
        expand = { "<CR>", "<2-LeftMouse>" },
        open = "o",
        remove = "d",
        repl = "r",
        toggle = "t"
    },
    render = {
        indent = 1,
        max_value_lines = 100
    }
}
)

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

require('dap-cortex-debug').setup {
    debug = false,  -- log debug messages
    -- path to cortex-debug extension, supports vim.fn.glob
    extension_path = '~/.vscode/extensions/marus25.cortex-debug-*/',
    lib_extension = nil, -- tries auto-detecting, e.g. 'so' on unix
    node_path = 'node', -- path to node.js executable
    dapui_rtt = false, -- register nvim-dap-ui RTT element
    dap_vscode_filetypes = { 'c', 'cpp' }, -- make :DapLoadLaunchJSON register cortex-debug for C/C++, set false to disable
}

