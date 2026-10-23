# Keymap Reference

`<leader>` is Space. `<localleader>` is `\`. Every mapping below has a
description and appears in WhichKey when its plugin/filetype is active.

## AI

| Mapping | Action |
| --- | --- |
| `<leader>aa` | CodeCompanion actions |
| `<leader>ac` | Toggle CodeCompanion chat |
| `<leader>ap` | CodeCompanion inline prompt |
| `<leader>ai` | Toggle Claude Code |
| `<leader>af` | Focus Claude Code |
| `<leader>ar` / `<leader>aC` | Resume / continue Claude Code |
| `<leader>ab` | Add current buffer to Claude Code |
| `<leader>as` | Send selected text to Claude Code |
| `<leader>ay` / `<leader>ad` | Accept / reject Claude Code diff |

Copilot completion uses the selected LazyVim completion integration. Each AI
tool keeps its own authentication; CodeCompanion's existing mappings stay intact.

## Code, data, and editing

| Mapping | Action |
| --- | --- |
| `<leader>cv` | Toggle virtual CSV/TSV column view |
| `<leader>cj` | Split or join the syntax node under the cursor |
| `<C-a>` / `<C-x>` | Dial increment / decrement |
| `g<C-a>` / `g<C-x>` | Dial sequential increment / decrement in a selection |
| `<leader>sy` | Open Yanky history in Snacks |
| `p` / `P` | Yanky put after / before |
| `gp` / `gP` | Yanky put after / before while leaving cursor after text |
| `[y` / `]y` | Cycle forward / backward through yank history |
| `<leader>uu` | Toggle Undotree |

Dial understands decimal/hex values, dates, weekdays, months, booleans, and
logical operators. It also supports Markdown checkboxes/headings, JSON
semantic versions, CSS colors, and language-specific logical/variable tokens.

## Navigation and outline

| Mapping | Action |
| --- | --- |
| `<leader>cs` | Toggle Aerial outline |
| `<leader>ss` | Search Aerial symbols with Telescope |
| `[a` / `]a` | Previous / next Aerial symbol |
| `<C-h/j/k/l>` | Move across Neovim splits or tmux panes |
| `<M-h/j/k/l>` | Resize the current split |

Split navigation stops at an edge when no tmux pane is available. Tmux
navigation is disabled while the tmux pane is zoomed.

## Git and GitHub

| Mapping | Action |
| --- | --- |
| `<leader>gvo` | Open Diffview |
| `<leader>gvf` | Current-file history in Diffview |
| `<leader>gvh` | Repository history in Diffview |
| `<leader>gvx` | Close Diffview |
| `<leader>gi` / `<leader>gI` | List / search GitHub issues in Octo |
| `<leader>gp` / `<leader>gP` | List / search GitHub pull requests in Octo |
| `<leader>gr` | List GitHub repositories in Octo |
| `<leader>go` | Search GitHub in Octo |
| `<leader>gS` | Git stash picker (preserved from LazyVim) |

Inside an Octo issue or PR buffer, `<localleader>` groups assignees, comments,
labels, issues, reactions, pull requests, reviews, and navigation. Use
`:Octo actions` for the context-sensitive action menu.

Roles remain separate:

- LazyGit performs Git operations.
- Diffview inspects diffs and history.
- Octo works with GitHub issues, PRs, reviews, comments, and threads.

## Notes

The vault is `~/Obsidian/AI Projects` unless `NVIM_NOTES_DIR` is set. Notes use
`<leader>o`; `<leader>n` retains LazyVim's notification history.

| Mapping | Action | Scope |
| --- | --- | --- |
| `<leader>oi` | Capture an idea without switching buffers | Global |
| `<leader>on` | New note in `00-inbox` | Global |
| `<leader>od` | Today's daily note | Global |
| `<leader>of` | Find notes with Snacks | Global |
| `<leader>os` | Search note contents | Global |
| `<leader>or` | Recent notes | Global |
| `<leader>oh` | Notes Home: searchable action menu | Global |
| `<leader>o?` | Beginner help (`q` / Esc closes) | Global |
| `<leader>om` | Format current note line | Vault buffer |
| `<leader>ox` | Toggle task unchecked / checked | Vault buffer |
| `<leader>ov` | Reveal / fold metadata | Vault buffer |
| `<leader>oz` | Toggle note focus mode | Vault buffer |
| `<leader>ot` | New note from a template | Global |
| `<leader>o#` | Search tags | Global |
| `<leader>ob` | Backlinks | Vault Markdown |
| `<leader>ol` | Links | Vault Markdown |
| `<leader>op` | Paste clipboard image | Vault Markdown |
| `<CR>` | Follow link / toggle checkbox | Vault Markdown |
| `]o` / `[o` | Next / previous link | Vault Markdown |
| `<leader>um` | Toggle Markdown rendering | After Markdown loads |
| `<leader>cp` | Toggle browser preview | Markdown |
| `<leader>cs` | Aerial outline | Global |
| `]a` / `[a` | Next / previous outline symbol | Global |
| `<leader>cf` | Format note on request | Global |

The leader is Space. Quick capture appends to `00-inbox/YYYY-MM-DD-ideas.md`.
Templates live in the vault's `templates/` folder. Vault notes auto-save on
InsertLeave, BufLeave, and FocusLost once the file exists.
`:NotesLint` runs style checks on request; automatic style lint remains active
outside the vault.

Type `[[` to complete a note
link, or select text and run `:Obsidian link`. See the [Notes guide](../README.md#notes)
for maintenance and image support.

## Requests and tasks

Global task mappings:

| Mapping | Action |
| --- | --- |
| `<leader>rr` | Select and run an Overseer task |
| `<leader>ra` | Act on an Overseer task |
| `<leader>rt` | Toggle the compact task list |

HTTP/REST buffers intentionally replace the first two mappings with
request-specific, buffer-local actions:

| Mapping | Action |
| --- | --- |
| `<leader>rr` | Run the request under the cursor |
| `<leader>ra` | Run all requests in the buffer |
| `<leader>ri` | Inspect the resolved request |
| `<leader>rc` | Copy the request as cURL |

Do not store production credentials directly in tracked `.http` files. Use
local environment files or buffer-scoped variables excluded from Git.

## UI and plugin maintenance

| Mapping or command | Action |
| --- | --- |
| `<leader>uH` | Toggle color highlighting for the current buffer |
| `<leader>fd` | Open the dashboard without closing a buffer |
| `<leader>bh` | Delete current buffer; show dashboard after the last buffer closes |
| `<leader>bd` | Existing LazyVim delete-buffer action |
| `<leader>uC` | Telescope theme preview; Enter saves, cancellation restores |
| `<leader>pu` / `:LazySafeUpdate` | Queue a verified update for normal exit |
| `<leader>ps` / `:LazySafeUpdateStatus` | Show latest updater result/log |
| `:LazySafeUpdateCancel` | Cancel an update queued in this process |
| `:Lazy` | Open the plugin manager |
| `:Lazy sync` | Match installed plugins to the lockfile/spec |
| `:Lazy update` | Update plugins and lockfile directly |
| `:Lazy check` | Check for upstream plugin changes |
| `:Lazy restore` | Restore revisions recorded in the lockfile |

Prefer the safe update wrapper over direct `:Lazy update`; it adds a snapshot,
validation, logging, and rollback.

Buffer deletion keeps Snacks' save/discard/cancel confirmation. Cancelling
preserves the buffer and does not replace it with the dashboard. Snacks owns
general navigation; Telescope is retained for the saved-theme picker.

Neotest core provides the global test mappings, but needs language adapters
before it can run tests. Markdown table mappings below are buffer-local and
retain their existing behavior in Markdown buffers.

## Markdown tables

Existing table mappings remain unchanged:

| Mapping | Action |
| --- | --- |
| `<leader>tt` | Insert a starter table |
| `<Tab>` / `<S-Tab>` | Next / previous table cell |
| `<leader>tr` / `<leader>tR` | Add row below / above |
| `<leader>tc` / `<leader>tH` | Add column right / left |
| `<leader>tC` | Delete column |

See [Markdown Table Workflow](markdown-tables.md) for details.
