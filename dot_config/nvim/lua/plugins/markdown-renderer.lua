-- Render Markdown for reading. This is intentionally separate from table-nvim:
-- it changes only the in-editor view, never the portable Markdown source.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "markdown.mdx" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      -- Keep rendered Markdown as the default reading view in every fresh
      -- Markdown session. Insert mode stays raw so normal editing remains safe.
      enabled = true,
      render_modes = { "n", "c", "t" },
      file_types = { "markdown", "markdown.mdx" },
      heading = { icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " } },
      checkbox = { enabled = true },
      anti_conceal = { enabled = true },
      win_options = { conceallevel = { default = vim.o.conceallevel, rendered = 2 } },
    },
  },
}
