return {
  {
    "folke/which-key.nvim",
    keys = {
      {
        "<leader>pu",
        function()
          require("config.safe_updates").queue_manual()
        end,
        desc = "Queue safe plugin update",
      },
      {
        "<leader>ps",
        function()
          require("config.safe_updates").status()
        end,
        desc = "Plugin update status",
      },
    },
    opts = {
      spec = {
        { "<leader>p", group = "plugins" },
      },
    },
  },
}
