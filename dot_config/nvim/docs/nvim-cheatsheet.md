# Neovim Keybindings and Workflow Cheat Sheet

`<leader>` is **Space**. This guide covers the useful mappings and workflows configured in this LazyVim setup, rather than every built-in Neovim command.

## Files and buffers

| Key or command              | Action                                                        |
| --------------------------- | ------------------------------------------------------------- |
| `<C-s>` or `:w`             | Save the current file                                         |
| `:wq` or `ZZ`               | Save and quit                                                 |
| `:q!`                       | Quit and discard unsaved changes                              |
| `<leader><space>`           | Find files from the project root                              |
| `<leader>e`                 | Open the Snacks file explorer                                 |
| `-`                         | Open the current file's parent folder in Oil                  |
| `<leader>,`                 | Switch buffers                                                |
| `H` / `L`                   | Previous / next buffer                                        |
| `<leader>bj`                | Pick a buffer                                                 |
| `<leader>bp`                | Pin or unpin buffer                                           |
| `<leader>bl` / `<leader>br` | Delete buffers to the left / right                            |
| `<leader>fr`                | Recent files                                                  |
| `<leader>fc`                | Find a Neovim configuration file                              |
| `:e path/to/file.md`        | Open a file; creates an unsaved buffer when it does not exist |
| `:enew`                     | Create an unnamed empty buffer                                |
| `:w copy.md`                | Save a copy while continuing to edit the current file         |
| `:saveas renamed.md`        | Save as a new name and continue editing that new file         |
| `:bdelete`                  | Close the current buffer without deleting its file            |
| `:e!`                       | Reload from disk and discard unsaved edits                    |
| `:file`                     | Show the current file name and status                         |

### File operations in Oil

Press `-` to edit the current directory as a buffer. In that directory buffer, add a filename and save with `:w` to create it; edit a filename and save to rename or move it; remove a filename line with `dd` and save to delete that file. Oil applies the operation on save, so review the buffer before writing.

## Search and jump

| Key                         | Action                                               |
| --------------------------- | ---------------------------------------------------- |
| `<leader>/`                 | Grep the project root                                |
| `<leader>sg` / `<leader>sG` | Grep the project root / current directory            |
| `<leader>sw` / `<leader>sW` | Search word under cursor in root / current directory |
| `<leader>sb`                | Search lines in the current buffer                   |
| `<leader>sr`                | Search and replace                                   |
| `<leader>sh`                | Search help pages                                    |
| `<leader>sk`                | Search keymaps                                       |
| `<leader>ss` / `<leader>sS` | Search document / workspace symbols                  |
| `<leader>:`                 | Command history                                      |
| `<leader>?`                 | Show keymaps available in the current buffer         |
| `s` / `S`                   | Flash jump / Tree-sitter Flash jump                  |
| `gx`                        | Open the link or file under the cursor               |

## Code, diagnostics, and editing

| Key                                | Action                                                               |
| ---------------------------------- | -------------------------------------------------------------------- |
| `[d` / `]d`                        | Previous / next diagnostic                                           |
| `<leader>xx`                       | Workspace diagnostics in Trouble                                     |
| `<leader>xX`                       | Current-buffer diagnostics in Trouble                                |
| `<leader>xL` / `<leader>xQ`        | Location list / quickfix list in Trouble                             |
| `gra`                              | Code action                                                          |
| `grn`                              | Rename symbol                                                        |
| `grr`                              | Find references                                                      |
| `gri`                              | Go to implementation                                                 |
| `grt`                              | Go to type definition                                                |
| `gO`                               | Show a document outline                                              |
| `<leader>cm`                       | Open Mason tool manager                                              |
| `<leader>cF`                       | Format injected languages                                            |
| `<leader>cS`                       | Browse LSP references, definitions, and related items in Trouble     |
| `gcc`                              | Toggle comment on the current line                                   |
| `gc`                               | Toggle comment using a motion or selection                           |
| `an` / `in` in Visual mode         | Select parent / child Tree-sitter node                               |
| `<C-Space>`                        | Start or expand Tree-sitter incremental selection                    |
| `<Tab>` / `<S-Tab>` in Insert mode | Jump through an active snippet; otherwise retain normal Tab behavior |

Language servers are configured for Lua, JavaScript/TypeScript, Python, Bash, JSON, YAML, and Go.

## Git, TODOs, sessions, and UI

| Key                         | Action                                     |
| --------------------------- | ------------------------------------------ |
| `<leader>gs`                | Git status                                 |
| `<leader>gc` / `<leader>gl` | Browse Git commits                         |
| `<leader>gS`                | Browse Git stashes                         |
| `[t` / `]t`                 | Previous / next TODO comment               |
| `<leader>st` / `<leader>sT` | List TODOs / TODO, FIX, and FIXME comments |
| `<leader>xt`                | Show TODOs in Trouble                      |
| `<leader>qs`                | Restore a saved session                    |
| `<leader>ql`                | Restore the last session                   |
| `<leader>qS`                | Select a session                           |
| `<leader>qd`                | Do not save the current session            |
| `<leader>n`                 | Notification history                       |
| `<leader>un`                | Dismiss notifications                      |
| `<leader>uC`                | Preview and select a colorscheme           |

## Personal tools

| Key                             | Action                              |
| ------------------------------- | ----------------------------------- |
| `<leader>ha`                    | Add the current file to Harpoon     |
| `<C-e>`                         | Open Harpoon's file menu            |
| `<leader>1` through `<leader>4` | Jump to Harpoon slots 1 through 4   |
| `<leader>aa`                    | Open CodeCompanion actions          |
| `<leader>ac`                    | Toggle CodeCompanion chat           |
| `<leader>ap`                    | Start a CodeCompanion inline prompt |

## Markdown tables

| Key                         | Action                             |
| --------------------------- | ---------------------------------- |
| `<leader>tt`                | Insert a starter table             |
| `<Tab>` / `<S-Tab>`         | Move to next / previous table cell |
| `<leader>tr` / `<leader>tR` | Insert a row below / above         |
| `<leader>tc` / `<leader>tH` | Insert a column right / left       |
| `<leader>tC`                | Delete the current column          |
| `dd`                        | Delete the current table row       |
| Leave Insert mode           | Align the table automatically      |

Table navigation applies only inside a parsed Markdown table. Outside a table, Tab keeps its usual completion, snippet, or indentation behavior. For a row removed with `dd`, briefly enter and leave Insert mode in the table if it needs re-alignment.

See [Markdown Table Workflow](markdown-tables.md) for a table-focused guide and removal/troubleshooting instructions.

## Viewing Markdown

Markdown is rendered automatically in every fresh Markdown or MDX session, including clean table borders and aligned cells. The current cursor line deliberately shows raw Markdown so you can edit it normally. Use `:RenderMarkdown toggle` to switch rendered viewing on or off for the current Neovim session.

## Setup defaults worth knowing

- Theme: Tokyo Night, `night` style.
- Relative line numbers, system clipboard integration, mouse support, undo history, and 2-space indentation are enabled.
- Tree-sitter highlighting and text objects cover the configured languages.
- Floating windows use rounded borders.
- Markdown rendering is enabled only for Markdown and MDX buffers; it changes the display, never the file contents.
- There is no direct delete-file keybinding. Use Oil and save its directory buffer so disk changes stay explicit.
