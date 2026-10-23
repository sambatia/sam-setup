return {
  {
    "nvim-telescope/telescope.nvim",
    lazy = true,
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- Snacks owns general navigation. Keep Telescope for the confirmed-theme
    -- persistence workflow rather than enabling two competing picker extras.
    keys = {
      {
        "<leader>uC",
        function()
          require("telescope.builtin").colorscheme({ enable_preview = true })
        end,
        desc = "Colorschemes",
      },
    },
    opts = function(_, opts)
      local actions = require("telescope.actions")

      -- Override LazyVim's buggy mappings to close the prompt first
      local find_files_no_ignore = function(prompt_bufnr)
        local action_state = require("telescope.actions.state")
        local line = action_state.get_current_line()
        actions.close(prompt_bufnr)
        require("telescope.builtin").find_files({ no_ignore = true, default_text = line })
      end

      local find_files_with_hidden = function(prompt_bufnr)
        local action_state = require("telescope.actions.state")
        local line = action_state.get_current_line()
        actions.close(prompt_bufnr)
        require("telescope.builtin").find_files({ hidden = true, default_text = line })
      end

      opts.defaults = opts.defaults or {}
      opts.defaults.mappings = opts.defaults.mappings or {}
      opts.defaults.mappings.i = opts.defaults.mappings.i or {}

      opts.defaults.mappings.i["<a-i>"] = find_files_no_ignore
      opts.defaults.mappings.i["<a-h>"] = find_files_with_hidden
    end,
  },
}
