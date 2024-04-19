local vim = vim
local Plug = vim.fn['plug#']

vim.call('plug#begin')
Plug('duane9/nvim-rg')
Plug('nvim-lualine/lualine.nvim')
Plug('nvim-tree/nvim-web-devicons')
Plug('nvim-telescope/telescope.nvim')
Plug('nvim-treesitter/nvim-treesitter')
Plug('nvim-lua/plenary.nvim')
Plug('kkoomen/vim-doge')
Plug('neovim/nvim-lspconfig')
Plug('hrsh7th/cmp-nvim-lsp-signature-help')
Plug('hrsh7th/nvim-cmp')
Plug('hrsh7th/cmp-nvim-lsp')
Plug('hrsh7th/cmp-buffer')
Plug('hrsh7th/cmp-path')
Plug('hrsh7th/cmp-cmdline')
Plug('hrsh7th/cmp-vsnip')
Plug('Mofiqul/vscode.nvim')
Plug('lewis6991/gitsigns.nvim')
Plug('nvimdev/guard.nvim')
Plug('nvimdev/guard-collection')
Plug('williamboman/mason-lspconfig.nvim')
Plug('williamboman/mason.nvim')
Plug('windwp/nvim-autopairs')
vim.call('plug#end')

