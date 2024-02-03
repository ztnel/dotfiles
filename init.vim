call plug#begin()
Plug 'duane9/nvim-rg'
Plug 'rebelot/kanagawa.nvim'
Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.5' }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/vim-vsnip'
Plug 'rstacruz/vim-closer'
Plug 'kkoomen/vim-doge', { 'do': { -> doge#install() } }
Plug 'Mofiqul/vscode.nvim'
Plug 'airblade/vim-gitgutter'
Plug 'lewis6991/gitsigns.nvim'
Plug 'nvimdev/guard.nvim'
Plug 'nvimdev/guard-collection'
call plug#end()

" Find files using Telescope command-line sugar.
nnoremap <C-p> <cmd>Telescope find_files<cr>

" Configure LSP for C
au FileType c nnoremap <buffer> K :lua vim.lsp.buf.hover()<CR>
augroup c_file_settings
  autocmd!
  autocmd FileType c setlocal tabstop=2 shiftwidth=2 expandtab omnifunc=v:lua.vim.lsp.omnifunc
  autocmd FileType cpp setlocal tabstop=2 shiftwidth=2 expandtab omnifunc=v:lua.vim.lsp.omnifunc
  autocmd FileType h setlocal tabstop=2 shiftwidth=2 expandtab omnifunc=v:lua.vim.lsp.omnifunc
augroup END

set showmatch               " show matching 
set ignorecase              " case insensitive 
set mouse=v                 " middle-click paste with 
set hlsearch                " highlight search 
set incsearch               " incremental search
set tabstop=4               " number of columns occupied by a tab 
set softtabstop=4           " see multiple spaces as tabstops so <BS> does the right thing
set expandtab               " converts tabs to white space
set number                  " add line numbers
set wildmode=longest,list   " get bash-like tab completions
filetype plugin indent on   "allow auto-indenting depending on file type
syntax on                   " syntax highlighting
set mouse=a                 " enable mouse click
set clipboard=unnamedplus   " using system clipboard
filetype plugin on
set cursorline              " highlight current cursorline
set ttyfast                 " Speed up scrolling in Vim
colorscheme vscode
set t_Co=256
let mapleader = ","
let g:gitgutter_enabled = 1
let g:webdevicons_enable = 1

lua << EOF
  vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
  vim.keymap.set("n", "gD", function() vim.lsp.buf.declaration() end, opts)
  local ft = require('guard.filetype')
  ft('c'):fmt('clang-format')
  require('guard').setup({
    -- the only options for the setup function
    fmt_on_save = true,
    -- Use lsp if no formatter was defined for this filetype
    lsp_as_default_formatter = false,
  })
  require('gitsigns').setup()
  -- Set up nvim-cmp.
  local cmp = require'cmp'
  cmp.setup({
    snippet = {
      -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
      end,
    },
    window = {
      -- completion = cmp.config.window.bordered(),
      -- documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'vsnip' }, -- For vsnip users.
    }, {
      { name = 'buffer' },
    })
  })

  -- Set configuration for specific filetype.
  cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
      { name = 'git' }, -- You can specify the `git` source if [you were installed it](https://github.com/petertriho/cmp-git).
    }, {
      { name = 'buffer' },
    })
  })

  -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline({ '/', '?' }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      { name = 'buffer' }
    }
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
      { name = 'path' }
    }, {
      { name = 'cmdline' }
    })
  })

  -- Set up lspconfig.
  local capabilities = require('cmp_nvim_lsp').default_capabilities()
  local lspconfig = require('lspconfig')
  lspconfig.clangd.setup{
    cmd = { 'clangd', '--compile-commands-dir=build' },
    filetypes = { 'c', 'cpp'},
    root_dir = lspconfig.util.root_pattern('compile_commands.json', 'compile_flags.txt', '.git'),
    settings = {
      clangd = {
        -- Include paths, replace with the paths relevant to your system
        compileCommands = { 'compile_commands.json' },
        systemIncludePaths = {
          '/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include',
        },
      },
    },
  }

  require('nvim-treesitter.configs').setup {
    highlight = {
      enable = true
    }
  }
  require('kanagawa').setup({
    compile = false,             -- enable compiling the colorscheme
    undercurl = true,            -- enable undercurls
    commentStyle = { italic = true },
    functionStyle = {},
    keywordStyle = { italic = true},
    statementStyle = { bold = true },
    typeStyle = {},
    transparent = false,         -- do not set background color
    dimInactive = false,         -- dim inactive window `:h hl-NormalNC`
    terminalColors = true,       -- define vim.g.terminal_color_{0,17}
    colors = {                   -- add/modify theme and palette colors
        palette = {},
        theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
    },
    overrides = function(colors) -- add/modify highlights
        return {}
    end,
    theme = "wave",              -- Load "wave" theme when 'background' option is not set
    background = {               -- map the value of 'background' option to a theme
        dark = "wave",           -- try "dragon" !
        light = "lotus"
    },
  })
  require('lualine').setup({
    options = {
        theme = 'vscode',
    },
})
EOF
