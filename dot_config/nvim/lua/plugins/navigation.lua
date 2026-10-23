return {
  {
    "mrjones2014/smart-splits.nvim",
    keys = {
      {
        "<C-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
        desc = "Go to left split or pane",
      },
      {
        "<C-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        desc = "Go to lower split or pane",
      },
      {
        "<C-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        desc = "Go to upper split or pane",
      },
      {
        "<C-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        desc = "Go to right split or pane",
      },
      {
        "<M-h>",
        function()
          require("smart-splits").resize_left()
        end,
        desc = "Resize split left",
      },
      {
        "<M-j>",
        function()
          require("smart-splits").resize_down()
        end,
        desc = "Resize split down",
      },
      {
        "<M-k>",
        function()
          require("smart-splits").resize_up()
        end,
        desc = "Resize split up",
      },
      {
        "<M-l>",
        function()
          require("smart-splits").resize_right()
        end,
        desc = "Resize split right",
      },
    },
    opts = {
      at_edge = "stop",
      default_amount = 3,
      disable_multiplexer_nav_when_zoomed = true,
    },
  },

  -- LazyVim supplies Aerial's LSP/Treesitter/Markdown backends and toggle.
  {
    "stevearc/aerial.nvim",
    keys = {
      { "[a", "<cmd>AerialPrev<cr>", desc = "Previous symbol" },
      { "]a", "<cmd>AerialNext<cr>", desc = "Next symbol" },
    },
  },
}
