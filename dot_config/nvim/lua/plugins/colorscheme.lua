return {
  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      -- One owner for theme confirmation/persistence, regardless of load order.
      return vim.tbl_filter(function(key)
        return key[1] ~= "<leader>uC"
      end, keys)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        require("config.colorscheme").load("kanagawa-wave")
      end,
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      pickers = {
        colorscheme = {
          attach_mappings = function(...)
            return require("config.colorscheme").attach_picker(...)
          end,
        },
      },
    },
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = true, -- Loaded when LazyVim applies the startup theme or the picker selects it.
    -- Upstream defaults: Wave, opaque backgrounds, undercurl and terminal colors;
    -- compilation stays disabled.
    opts = {},
  },
}
