-- Overrides for LazyVim's own plugin specs.
-- LazyVim already provides these plugins; we only extend their `opts`.
-- lazy.nvim merges these with LazyVim's spec rather than replacing it.

return {
  -- Colorscheme: LazyVim ships tokyonight and sets it as the default,
  -- but with style = "moon". The pre-migration config used "night".
  {
    "folke/tokyonight.nvim",
    opts = { style = "night" },
  },

  -- LSP servers. LazyVim installs lua_ls by default and adds others via its
  -- `lang.*` extras. Rather than importing seven extras, declare the exact
  -- server list the pre-migration config used. mason-lspconfig auto-installs
  -- and vim.lsp.enable()s each one.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
        ts_ls = {},
        pyright = {},
        bashls = {},
        yamlls = {},
        gopls = {},
      },
    },
  },

  -- Treesitter parsers. LazyVim's spec already pins branch = "main" (matching
  -- the pre-migration config) and enables highlight/indent/folds. `opts_extend`
  -- on LazyVim's side means this list is appended, not replaced.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = require("config.treesitter_languages"),
    },
  },

  -- blink.cmp: LazyVim pins and configures it. The pre-migration config pinned
  -- v1 explicitly "for stability". Keep that pin; drop the rest (LazyVim's
  -- defaults already cover keymap/appearance/sources/snippets/documentation).
  {
    "saghen/blink.cmp",
    version = "1.*",
  },
}
