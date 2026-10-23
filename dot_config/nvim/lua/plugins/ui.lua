return {
  {
    "nvim-mini/mini.hipatterns",
    opts = function(_, opts)
      -- Colorizer already owns ordinary hex colors. This extra adds Tailwind
      -- class highlighting without a second set of hex-color extmarks.
      opts.highlighters.hex_color = nil
      opts.highlighters.shorthand = nil
    end,
  },
  {
    "catgoose/nvim-colorizer.lua",
    cmd = {
      "ColorizerToggle",
      "ColorizerAttachToBuffer",
      "ColorizerDetachFromBuffer",
      "ColorizerReloadAllBuffers",
    },
    ft = {
      "css",
      "scss",
      "sass",
      "html",
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "lua",
    },
    keys = {
      { "<leader>uH", "<cmd>ColorizerToggle<cr>", desc = "Toggle color highlights" },
    },
    opts = {
      filetypes = {
        "css",
        "scss",
        "sass",
        "html",
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "lua",
      },
      lazy_load = true,
      user_commands = true,
      options = {
        parsers = {
          css = true,
          css_fn = true,
          names = { enable = false },
          tailwind = {
            enable = false,
            lsp = { enable = false },
          },
        },
        display = {
          mode = "background",
          -- Colorizer is authoritative for these filetypes; do not render a
          -- second set of Neovim LSP document-color extmarks.
          disable_document_color = true,
        },
        debounce_ms = 40,
      },
    },
  },
}
