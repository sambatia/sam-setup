return {
  {
    "mistweaverco/kulala.nvim",
    -- Exact pin. Each kulala release requires one kulala-core build and
    -- downloads it on a mismatch. 6.32.0 (2026-09-29) gets builds only with a
    -- license token and prompts for one at every start, which blocks headless
    -- Neovim. The public builds that 6.23 through 6.31 fetched are gone
    -- (dont-be-evil-company/kulala-core returns 404). 6.22.0 requires the
    -- kulala-core 0.29.1 installed here on 2026-07-25, so it works with no
    -- download and no prompt. A fresh machine cannot fetch any build without
    -- a license. Lift the pin once KULALA_CORE_LICENSE_TOKEN is set.
    version = "6.22.0",
    ft = { "http", "rest" },
    keys = {
      {
        "<leader>rr",
        function()
          require("kulala").run()
        end,
        mode = { "n", "x" },
        ft = { "http", "rest" },
        desc = "Run HTTP request",
      },
      {
        "<leader>ra",
        function()
          require("kulala").run_all()
        end,
        mode = { "n", "x" },
        ft = { "http", "rest" },
        desc = "Run all HTTP requests",
      },
      {
        "<leader>ri",
        function()
          require("kulala").inspect()
        end,
        ft = { "http", "rest" },
        desc = "Inspect HTTP request",
      },
      {
        "<leader>rc",
        function()
          require("kulala").copy()
        end,
        ft = { "http", "rest" },
        desc = "Copy request as cURL",
      },
    },
    opts = {
      global_keymaps = false,
      session = {
        -- Responses may contain credentials or private data; do not serialize
        -- request history into Neovim session files.
        restore = false,
      },
      kulala_core = {
        timeout = 30000,
        download_tool = "curl",
      },
      treesitter = {
        enable = true,
        cli_path = "tree-sitter",
      },
      environment_scope = "b",
      lsp = {
        enable = true,
        filetypes = { "http", "rest" },
        keymaps = false,
      },
      debug = 1,
      generate_bug_report = false,
      ui = {
        display_mode = "split",
        split_direction = "right",
        max_response_size = 32768,
        max_request_size = 2048,
        show_variable_info_text = false,
      },
    },
  },

  -- LazyVim supplies Overseer's task UI and built-in npm/pnpm/bun, make,
  -- just, and cargo providers. Keep it out of startup; inherited commands and
  -- these mappings load it on first use.
  {
    "stevearc/overseer.nvim",
    lazy = true,
    keys = {
      { "<leader>ow", false },
      { "<leader>oo", false },
      { "<leader>ot", false },
      { "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>ra", "<cmd>OverseerTaskAction<cr>", desc = "Task action" },
      { "<leader>rt", "<cmd>OverseerToggle!<cr>", desc = "Toggle task list" },
    },
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>o", group = "obsidian" },
        { "<leader>r", group = "run / requests" },
      },
    },
  },
}
