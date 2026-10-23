# LazyVim Production Upgrade Design

**Date:** 2026-07-25  
**Status:** Approved  
**Target:** `~/.config/nvim` (`dotfiles/nvim` in `star-setup`)

## Goals

Upgrade the existing LazyVim configuration without replacing it, losing local
customizations, duplicating built-in behavior, or making startup depend on the
network. The resulting configuration must remain reproducible through
`lazy-lock.json`, load heavy plugins on demand, expose coherent keymaps, and
provide an automatic update path with verification and rollback.

## Baseline

- Neovim 0.12.4
- LazyVim 16.0.0
- lazy.nvim 11.17.5
- macOS 26.5.2 on Apple Silicon
- Baseline startup: 28.828 ms
- Picker: Telescope extra
- Completion: blink.cmp
- File navigation: Snacks Explorer and Oil
- Git: Gitsigns, Snacks Git helpers, and LazyGit
- UI: Snacks and Noice
- Markdown: render-markdown.nvim and table-nvim
- AI: CodeCompanion only
- Existing configuration backup:
  `/Users/sam/.config/nvim.backup.20260725-023926`

The Neovim config is a symlink into a larger repository with unrelated dirty
files. Neovim-only pre-upgrade changes are captured in a dedicated baseline
commit. Implementation will occur in an isolated worktree and will be merged
back only after validation.

## Selection Principles

1. Prefer LazyVim extras over hand-written specifications when an extra exists.
2. Prefer existing LazyVim, Snacks, Noice, blink.cmp, and mini.nvim behavior
   over an additional plugin.
3. Require a distinct workflow, current maintenance, compatible Neovim
   requirements, and an observable lazy-load boundary for every addition.
4. Pin the resolved commits in `lazy-lock.json`; use stable release ranges only
   when upstream explicitly recommends them.
5. Do not configure credentials, remote MCP servers, or external AI agents
   without a concrete use case and an existing secure credential path.

## Approved Additions

| Plugin or extra | Decision and role | Load boundary |
| --- | --- | --- |
| `hat0uma/csvview.nvim` | CSV/TSV/semicolon-delimited display without changing source text | CSV/TSV filetypes, commands, or `<leader>cv` |
| `dlyongemallo/diffview-plus.nvim` | Maintained replacement for dormant `sindrets/diffview.nvim`; repository/file history and merge inspection | Diffview commands and Git keymaps |
| `lazyvim.plugins.extras.util.octo` | GitHub issues, pull requests, reviews, comments, and threads | `:Octo`, Octo URIs, and GitHub keymaps |
| `lazyvim.plugins.extras.editor.aerial` | Persistent LSP/Tree-sitter/Markdown symbol outline | LazyFile and symbol keymaps |
| `Wansmer/treesj` | Syntax-aware split/join | command or `<leader>cj` |
| `mrjones2014/smart-splits.nvim` | Neovim/tmux-aware split navigation and resizing | navigation and resize keys |
| `lazyvim.plugins.extras.coding.yanky` | Yank ring integrated with Telescope | LazyFile and yank/paste keys |
| `lazyvim.plugins.extras.editor.dial` | Numbers, dates, booleans, Markdown tasks, and semantic versions | increment/decrement keys |
| `mbbill/undotree` | Persistent visual undo history, distinct from the inactive Snacks undo picker | command or `<leader>uu` |
| `lazyvim.plugins.extras.lang.json` | SchemaStore-backed JSON validation and completion | JSON LSP initialization |
| `catgoose/nvim-colorizer.lua` | Maintained canonical colorizer with restricted filetypes and no duplicate LSP color parsing | selected web/config filetypes or toggle |
| `obsidian-nvim/obsidian.nvim` | Maintained Obsidian integration for the detected vault only | vault Markdown reads/new files or `:Obsidian` |
| `mistweaverco/kulala.nvim` | HTTP/REST request execution and response inspection | HTTP/REST filetypes and commands |
| `lazyvim.plugins.extras.editor.overseer` | Project task discovery, execution, and history | Overseer commands and task keymaps |

The existing `render-markdown.nvim` and `table-nvim` remain the sole Markdown
renderer and table editor. No additional renderer or table plugin will be
installed.

## Rejected or Replaced Candidates

| Candidate | Classification | Reason |
| --- | --- | --- |
| `sindrets/diffview.nvim` | Replace | Last code update was in 2024. diffview+ preserves the command/API model and is actively maintained. |
| `NeogitOrg/neogit` | Skip — duplicate | LazyGit already owns interactive Git operations. Diffview+ is inspection; Octo is GitHub collaboration. |
| Git link generator | Skip — duplicate | `Snacks.gitbrowse()` already opens and copies repository links. |
| Additional blame viewer | Skip — duplicate | Snacks supplies line history and Gitsigns supplies line/buffer blame. |
| `RRethy/vim-illuminate` | Skip — duplicate | LazyVim already enables `Snacks.words` for reference highlighting/navigation. |
| Additional outline plugin | Skip — duplicate | Aerial is the single persistent outline; native/LSP pickers remain available. |
| `j-hui/fidget.nvim` | Skip — duplicate | Noice already owns LSP progress and message presentation. |
| `kevinhwang91/nvim-bqf` | Skip — duplicate | Trouble and Telescope already cover quickfix/location-list presentation and preview. |
| `NvChad/nvim-colorizer.lua` | Replace | The canonical maintained repository is now `catgoose/nvim-colorizer.lua`. |
| `epwalsh/obsidian.nvim` | Replace | The maintained successor is `obsidian-nvim/obsidian.nvim`. |
| JSON/JQ plugin | Skip — unnecessary | `jq` is installed; JSON LSP plus SchemaStore supplies editor value without another UI. |
| SQLite plugin | Skip — unnecessary | SQLite is installed and no selected plugin requires a Lua SQLite dependency. |
| LazyDocker plugin | Skip — duplicate | The installed `lazydocker` executable can run through `Snacks.terminal`. |
| Kubernetes plugin | Skip — unspecified | Tooling exists, but no concrete Neovim workflow justifies a permanent plugin. |
| Additional AI/agent plugins | Skip — duplicate | CodeCompanion remains the sole in-editor AI layer. |
| CodeCompanion MCP servers | Optional, not configured | MCP is built in, but no server has a scoped requirement or credential policy. |
| OpenCode/Aider integration | Optional, not configured | Both CLIs exist, but adding overlapping agent keymaps would blur the single-AI architecture. |

## Configuration Architecture

Keep the existing small files and add category modules rather than rewrite the
configuration:

```text
lua/plugins/
├── ai.lua
├── data.lua
├── editing.lua
├── editor.lua
├── git.lua
├── markdown.lua
├── markdown-renderer.lua
├── markdown-tables.lua
├── navigation.lua
├── overrides.lua
├── tasks.lua
├── ui.lua
└── updates.lua
```

LazyVim extras will be recorded in `lazyvim.json`, including the existing
Telescope selection, so `:LazyExtras` and future audits see the authoritative
state. Custom plugin files will contain only configuration not supplied by an
extra. `opts`, `cmd`, `ft`, `event`, and `keys` will be preferred over eager
`config` functions.

## Keymap Design

- `<leader>a`: CodeCompanion
- `<leader>c`: code/data (`<leader>cv`, `<leader>cj`)
- `<leader>gd`: Diffview+ (`o` open, `f` file history, `h` repository history,
  `x` close)
- `<leader>g`: existing Git plus Octo; preserve `<leader>gS` for stashes and use
  `<leader>go` for Octo search
- `<leader>o`: Obsidian
- `<leader>r`: requests, tasks, and developer tools
- `<leader>u`: UI/utilities
- `<leader>p`: plugin maintenance (`<leader>pu`)

Overseer owns global `<leader>rr`, `<leader>ra`, and `<leader>rt`. Kulala uses
buffer-local versions of `<leader>rr`, `<leader>ra`, `<leader>ri`, and
`<leader>rc` in HTTP/REST buffers, where the request-specific action is more
relevant. All mappings receive descriptions and are tested against the
effective LazyVim keymap set.

## Obsidian Policy

The detected workspace is `~/Obsidian/AI Projects`. The plugin will use the
latest stable v3 release range as upstream recommends, load for Markdown files
inside that workspace (or explicit `:Obsidian` commands), and use its in-process
LSP so blink.cmp consumes standard LSP completions. Daily notes are enabled.
No templates folder was detected, so a template path will not be invented.
Rendering remains owned by render-markdown.nvim.

## CodeCompanion Policy

Preserve the Anthropic adapter and macOS Keychain command. Migrate the
soon-to-be-removed `strategies` option to `interactions`. Do not add keys,
servers, or agent adapters. `:checkhealth codecompanion` must pass without
requiring a credential; a missing Keychain entry must remain a request-time,
non-startup failure.

## Update and Rollback Design

### Installation and checks

- `lazy.nvim` continues to bootstrap from its stable branch when missing.
- `install.missing = true` makes declared missing plugins install
  automatically.
- lazy.nvim's asynchronous checker runs at most once every 86,400 seconds,
  records its timestamp in `~/.local/state/nvim/lazy/state.json`, and notifies
  only when updates exist.
- No network call blocks the startup path.

### Controlled updates

Automatic updates are eligible no more than once every seven days and run only
after an interactive Neovim process exits. Eligibility requires:

- a valid preflight startup;
- a clean Git state for the Neovim subtree;
- no existing updater lock;
- an existing full baseline backup;
- a valid `lazy-lock.json`.

The updater acquires an atomic lock, copies the lockfile to a timestamped state
snapshot, logs all commands, runs a headless Lazy update, and validates startup,
the Lazy specification, core health checks, and the lockfile. On any failure it
restores the prior lockfile, runs `Lazy restore`, revalidates startup, records a
failed result, and leaves the diagnostic log and snapshot in place.

The next interactive startup reports the result. A manual safe-update command
and `<leader>pu` use the same implementation. Built-in `:Lazy`, `:Lazy sync`,
`:Lazy update`, `:Lazy check`, and `:Lazy restore` remain available and are
documented, but the safe wrapper is the recommended update entry point.

No launchd job will be installed. Updating after the final interactive process
exits avoids login-time work and reduces concurrent modification risk.

## Verification Strategy

1. Add failing headless assertions for plugin declarations, lazy boundaries,
   update-policy decisions, keymaps, and commands.
2. Implement the minimum configuration to satisfy those assertions.
3. Synchronize in isolated XDG data/state directories.
4. Exercise CSV source preservation, Treesj, Dial, Yanky, Undotree, Aerial,
   Diffview+, Octo command loading, Obsidian workspace attachment, Kulala
   command loading, Overseer discovery, and CodeCompanion health.
5. Test updater eligibility, lock acquisition, successful dry-run, simulated
   validation failure, lockfile restoration, and log creation.
6. Format Lua with a project-local or temporary Stylua binary.
7. Run Lazy sync/check, scoped health checks, full health capture, startup
   profiling, secret scanning, and final Git diff review.

Interactive-only behavior that cannot be asserted headlessly will be smoke
tested through command execution and documented honestly rather than reported
as visually verified.

## Authoritative Sources

- [LazyVim documentation](https://www.lazyvim.org/)
- [lazy.nvim documentation](https://lazy.folke.io/)
- [csvview.nvim](https://github.com/hat0uma/csvview.nvim)
- [diffview+](https://github.com/dlyongemallo/diffview-plus.nvim)
- [Octo.nvim](https://github.com/pwntester/octo.nvim)
- [Aerial.nvim](https://github.com/stevearc/aerial.nvim)
- [TreeSJ](https://github.com/Wansmer/treesj)
- [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim)
- [yanky.nvim](https://github.com/gbprod/yanky.nvim)
- [dial.nvim](https://github.com/monaqa/dial.nvim)
- [SchemaStore.nvim](https://github.com/b0o/SchemaStore.nvim)
- [nvim-colorizer.lua](https://github.com/catgoose/nvim-colorizer.lua)
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- [Kulala](https://github.com/mistweaverco/kulala.nvim)
- [Overseer](https://github.com/stevearc/overseer.nvim)
- [CodeCompanion](https://github.com/olimorris/codecompanion.nvim)
