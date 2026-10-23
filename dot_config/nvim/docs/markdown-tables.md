# Markdown Table Workflow

## Installed solution

This configuration uses [SCJangra/table-nvim](https://github.com/SCJangra/table-nvim), a Tree-sitter-powered Markdown table editor. It was chosen over formatting-only alternatives because it creates tables, navigates cells with context-aware Tab keys, edits rows and columns, and keeps ordinary Markdown output. Its only dependency, `nvim-treesitter`, is already part of LazyVim.

Configuration: `lua/plugins/markdown-tables.lua`.

It lazy-loads only for `markdown` and `markdown.mdx` buffers. LazyVim's full `lang.markdown` extra remains disabled: table editing has no need for its browser preview, Markdown LSP, or extra formatters. `render-markdown.nvim` is installed separately for an in-editor rendered view; it never changes the Markdown source.

## Daily use

| Key | Action |
| --- | --- |
| `<leader>tt` | Insert a three-row, two-column table |
| `<Tab>` / `<S-Tab>` | Next / previous cell inside a table; normal LazyVim behavior elsewhere |
| `<leader>tr` / `<leader>tR` | Insert a row below / above |
| `<leader>tc` / `<leader>tH` | Insert a column right / left |
| `<leader>tC` | Delete the current column |
| `dd` | Delete the current table row with standard Neovim line deletion |
| `u` / `<C-r>` | Undo / redo table edits |

Table-nvim aligns the current table when leaving Insert mode and immediately after its structural commands. For a row removed with `dd`, enter and leave Insert mode in the table once to trigger the usual alignment pass.

Example output remains portable Markdown:

```markdown
| Owner | Status |
| --- | --- |
| Sam | ✅ Complete |
| Team | 🚧 In progress |
```

## Troubleshooting and maintenance

- Plugin absent or mappings unavailable: run `:Lazy sync`, reopen a Markdown buffer, then inspect `:Lazy`.
- Tab is not moving between cells: place the cursor in a parsed pipe table; outside a table it intentionally retains normal completion/snippet behavior.
- Table not aligned: leave Insert mode while the cursor is inside that table. Tree-sitter's `markdown` parser must be installed (`:checkhealth vim.treesitter`).
- Rendered view versus raw syntax: use `:RenderMarkdown toggle`. The cursor line intentionally remains raw for editing.
- Update normally with `:Lazy update SCJangra/table-nvim`; run `:checkhealth` and reopen a Markdown file afterward.

## Removal and rollback

1. Delete `lua/plugins/markdown-tables.lua`.
2. Run `:Lazy clean` and restart Neovim.
3. To restore the pre-install lockfile, copy `backups/lazy-lock.json.20260714-155050.bak` over `lazy-lock.json` (only if rolling back this change), then run `:Lazy sync`.
4. Start `nvim --headless +qa` to verify a clean startup.

The plugin creates no proprietary syntax and can be removed without changing Markdown files.
