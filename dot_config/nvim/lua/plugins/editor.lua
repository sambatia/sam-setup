-- Editor plugins that LazyVim does not ship.
--
-- Note on file explorers: LazyVim binds <leader>e to neo-tree. The
-- pre-migration config documented "decided: Oil — buffer-as-filesystem; NOT
-- neo-tree". Both are kept: Oil on its native `-` (open parent dir), neo-tree
-- left on <leader>e. They do different things and don't conflict. If you want
-- neo-tree gone entirely, add `{ "nvim-neo-tree/neo-tree.nvim", enabled = false }`
-- and remap <leader>e to `<cmd>Oil<cr>`.

return {
  -- File explorer as a normal buffer.
  {
    "stevearc/oil.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { view_options = { show_hidden = true } },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent dir (Oil)" },
    },
  },

  -- Quick file navigation. <leader>1..4 are free in LazyVim (it uses <S-h>/<S-l>,
  -- [b/]b and <leader>b* for buffers), so the original bindings carry over as-is.
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>ha",
        function()
          require("harpoon"):list():add()
        end,
        desc = "Harpoon add",
      },
      {
        "<C-e>",
        function()
          local h = require("harpoon")
          h.ui:toggle_quick_menu(h:list())
        end,
        desc = "Harpoon menu",
      },
      {
        "<leader>1",
        function()
          require("harpoon"):list():select(1)
        end,
        desc = "Harpoon 1",
      },
      {
        "<leader>2",
        function()
          require("harpoon"):list():select(2)
        end,
        desc = "Harpoon 2",
      },
      {
        "<leader>3",
        function()
          require("harpoon"):list():select(3)
        end,
        desc = "Harpoon 3",
      },
      {
        "<leader>4",
        function()
          require("harpoon"):list():select(4)
        end,
        desc = "Harpoon 4",
      },
    },
    config = function()
      require("harpoon"):setup()
    end,
  },
}
