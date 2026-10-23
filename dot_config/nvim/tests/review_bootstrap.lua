-- Runtime QA uses installed plugins, never installs, updates, or starts AI.
local lazy_root = assert(vim.env.NVIM_REVIEW_LAZY_ROOT, "installed plugin root is required")
assert(vim.uv.fs_stat(lazy_root .. "/lazy.nvim/lua/lazy/init.lua"), "lazy.nvim must already be installed")
vim.opt.rtp:prepend(lazy_root .. "/lazy.nvim")
vim.g.safe_plugin_updates_enabled = false
local lazy = require("lazy")
local setup = lazy.setup
lazy.setup = function(opts)
  opts.root = lazy_root
  opts.install.missing = false
  opts.checker.enabled = false
  opts.spec[#opts.spec + 1] = {
    -- Keep the real plugin set/keys, but prevent background maintenance and AI
    -- activation in this QA process. Production settings are not changed.
    {
      "zbirenbaum/copilot.lua",
      event = function()
        return {}
      end,
    },
    {
      "mason-org/mason.nvim",
      opts = function(_, o)
        o.ensure_installed = {}
      end,
    },
    { "mason-org/mason-lspconfig.nvim", opts = { automatic_enable = false } },
    {
      "neovim/nvim-lspconfig",
      opts = function(_, o)
        for _, server in pairs(o.servers) do
          if type(server) == "table" then
            server.mason = false
          end
        end
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, o)
        o.ensure_installed = {}
      end,
    },
  }
  setup(opts)
  lazy.setup = setup
end
