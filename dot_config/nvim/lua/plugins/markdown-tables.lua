-- Markdown table editing. Keep this narrowly scoped: table-nvim provides
-- structural editing and formatting, while renderers/previews stay optional.
return {
  {
    "SCJangra/table-nvim",
    ft = { "markdown", "markdown.mdx" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      -- Matches conventional, portable GitHub-flavored Markdown tables.
      padd_column_separators = true,
      mappings = {
        -- table-nvim returns the original key outside a table, preserving
        -- LazyVim completion, snippets, and indentation in all other contexts.
        next = "<Tab>",
        prev = "<S-Tab>",
        insert_table = "<leader>tt",
        insert_table_alt = false,
        insert_row_up = "<leader>tR",
        insert_row_down = "<leader>tr",
        move_row_up = false,
        move_row_down = false,
        insert_column_left = "<leader>tH",
        insert_column_right = "<leader>tc",
        move_column_left = false,
        move_column_right = false,
        delete_column = "<leader>tC",
      },
    },
  },
}
