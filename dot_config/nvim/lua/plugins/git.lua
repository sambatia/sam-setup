return {
  -- Actively maintained, command-compatible continuation of Diffview.
  {
    "dlyongemallo/diffview-plus.nvim",
    version = "*",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
    },
    keys = {
      { "<leader>gvo", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
      { "<leader>gvf", "<cmd>DiffviewFileHistory %<cr>", desc = "Current file history (Diffview)" },
      { "<leader>gvh", "<cmd>DiffviewFileHistory<cr>", desc = "Repository history (Diffview)" },
      { "<leader>gvx", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        merge_tool = {
          layout = "diff3_mixed",
          disable_diagnostics = true,
        },
      },
    },
  },

  -- LazyVim's Octo extra owns the complete PR/issue/review workflow. Preserve
  -- Telescope's Git-stash mapping and relocate only Octo's overlapping search.
  {
    "pwntester/octo.nvim",
    opts = {
      -- LazyVim enables Projects v2 by default, but issue/PR/review workflows
      -- do not require its additional GitHub token scope.
      default_to_projects_v2 = false,
    },
    keys = {
      { "<leader>gS", false },
      { "<leader>go", "<cmd>Octo search<cr>", desc = "Search GitHub (Octo)" },
    },
  },
}
