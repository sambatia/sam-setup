# Plugin Audit

Audit date: 2026-07-25

## Reviewed configuration update: 2026-10-01

This dated update supersedes the original single-AI and Telescope-only choices
below; the July tables remain a historical audit, not the current inventory.
Sam approved review and adoption of the existing extras and lockfile changes.

- Snacks owns general navigation. Telescope stays lazy-loaded for the saved
  theme picker, with its own dependency and shortcut. Snacks' competing theme
  mapping is removed so plugin load order cannot change confirmation behavior.
- Claude Code and Copilot extras are retained. CodeCompanion keeps `<leader>aa`,
  `<leader>ac`, and `<leader>ap`; Claude toggle and diff acceptance move to
  `<leader>ai` and `<leader>ay`. Authentication and agent permissions are unchanged.
- Inc-rename, dotfile support, and Neotest core are retained. Neotest still needs
  language adapters before it can run tests; none are installed by this review.
- mini.hipatterns adds Tailwind class colors only. Colorizer remains the owner
  of ordinary hex-color highlighting.
- Dashboard shortcuts use Snacks' safe buffer-deletion confirmation. Cancelling
  keeps unsaved work and does not switch to the dashboard.

The reviewed 62-plugin set exactly matched installed checkout revisions.
Deterministic regression tests and guarded installed-runtime tests cover the
resolved lockfile, effective mappings, real Snacks cancellation, and theme
preview/Enter/cancel/restart. QA does not start an AI client or make an AI request.
See [Keymaps](keymaps.md) and `sh tests/review-runtime.sh`.

## Environment and initial state

| Item | Detected |
| --- | --- |
| Neovim | 0.12.4 |
| LazyVim | 16.0.0 |
| lazy.nvim | 11.17.5 |
| macOS | 26.5.2, Apple Silicon |
| Package/version managers | Homebrew, mise, Mason, npm, pnpm, bun, Cargo, Go |
| Picker | Telescope |
| Completion | blink.cmp |
| File navigation | Snacks Explorer and Oil |
| Git | Gitsigns, Snacks Git helpers, LazyGit |
| Markdown | render-markdown.nvim and table-nvim |
| AI | CodeCompanion |
| Baseline startup | 28.828 ms |

The live config was already a LazyVim setup and a symlink into a larger,
partially dirty repository. Unrelated repository changes were preserved. A
full timestamped copy was made at
`~/.config/nvim.bak-<timestamp>`, and Neovim-only baseline
state was committed before implementation.

Important initial findings:

- LazyVim extras were partly implicit instead of authoritative in
  `lazyvim.json`.
- CodeCompanion still used the deprecated `strategies` configuration shape.
- CodeCompanion was already the single AI layer and had a safe macOS Keychain
  credential path.
- Oil/Snacks, Telescope, blink.cmp, Noice/Snacks, render-markdown, Gitsigns,
  and LazyGit already covered several proposed plugin categories.
- Full headless health had pre-existing optional-provider and Snacks
  terminal/image warnings; scoped core health was clean.

## Decision matrix

| Candidate | Classification | Decision |
| --- | --- | --- |
| `hat0uma/csvview.nvim` | **INSTALL** | Virtual CSV/TSV/delimited alignment; source remains untouched. |
| JSON/JQ integration | **KEEP EXISTING** | `jq` plus JSON LSP and SchemaStore cover the workflow. |
| SQLite support | **SKIP — UNNECESSARY** | Installed system SQLite is sufficient; no selected plugin needs a Lua binding. |
| `sindrets/diffview.nvim` | **REPLACE WITH `dlyongemallo/diffview-plus.nvim`** | The original repository is dormant; the maintained fork preserves the workflow. |
| `pwntester/octo.nvim` | **INSTALL (LazyVim extra)** | Distinct GitHub issue/PR/review role; authenticated `gh` is available. Projects v2 defaults are disabled because its extra token scope is absent and unnecessary. |
| `NeogitOrg/neogit` | **SKIP — DUPLICATE** | LazyGit already owns interactive Git operations. |
| Git link generator | **SKIP — DUPLICATE** | `Snacks.gitbrowse()` opens or copies remote links. |
| Additional blame viewer | **SKIP — DUPLICATE** | Gitsigns and Snacks already provide blame and line history. |
| `stevearc/aerial.nvim` | **INSTALL (LazyVim extra)** | Single persistent LSP/Tree-sitter/Markdown outline. |
| `Wansmer/treesj` | **INSTALL** | Syntax-aware split/join is not otherwise present. |
| `mrjones2014/smart-splits.nvim` | **INSTALL** | Consistent Neovim/tmux navigation and resizing. |
| `RRethy/vim-illuminate` | **SKIP — DUPLICATE** | `Snacks.words` already highlights and navigates references. |
| Additional symbol outline | **SKIP — DUPLICATE** | Aerial is authoritative. |
| `gbprod/yanky.nvim` | **INSTALL (LazyVim extra)** | Yank history while preserving normal paste semantics and Telescope integration. |
| `monaqa/dial.nvim` | **INSTALL (LazyVim extra)** | Numbers, dates, booleans, Markdown tasks, and semantic versions. |
| `mbbill/undotree` | **INSTALL** | Persistent visual undo history has a distinct role. |
| `b0o/SchemaStore.nvim` | **INSTALL (JSON extra)** | Current JSON schema catalog for jsonls completion and validation. |
| `folke/todo-comments.nvim` | **KEEP EXISTING** | Already supplied by LazyVim. |
| `MagicDuck/grug-far.nvim` | **KEEP EXISTING** | Already supplied by LazyVim. |
| `folke/trouble.nvim` | **KEEP EXISTING** | Already supplied by LazyVim. |
| `j-hui/fidget.nvim` | **SKIP — DUPLICATE** | Noice owns LSP progress and messages. |
| `NvChad/nvim-colorizer.lua` | **REPLACE WITH `catgoose/nvim-colorizer.lua`** | Canonical maintained home; restricted to relevant filetypes. |
| `kevinhwang91/nvim-bqf` | **SKIP — DUPLICATE** | Trouble and Telescope cover list presentation and preview. |
| `epwalsh/obsidian.nvim` | **REPLACE WITH `obsidian-nvim/obsidian.nvim`** | Maintained successor, enabled only because a vault exists. |
| Existing Markdown renderer | **KEEP EXISTING** | render-markdown remains the sole renderer. |
| Existing Markdown table editor | **KEEP EXISTING** | table-nvim remains the sole table editor. |
| `mistweaverco/kulala.nvim` | **INSTALL** | Filetype-scoped HTTP/REST requests with no persisted response session. |
| `stevearc/overseer.nvim` | **INSTALL (LazyVim extra)** | Project task discovery/execution with tool detection. |
| LazyDocker plugin | **SKIP — DUPLICATE** | Installed `lazydocker` can run through Snacks terminal. |
| Kubernetes plugin | **OPTIONAL / NOT CONFIGURED** | CLI exists, but no concrete editor workflow was established. |
| Existing CodeCompanion | **KEEP EXISTING** | Single in-editor AI layer; migrated to `interactions` and constrained to its compatible v19 release line. |
| CodeCompanion MCP | **OPTIONAL / NOT CONFIGURED** | No scoped server requirement or credential policy justified configuration. |
| OpenCode/Aider integration | **OPTIONAL / NOT CONFIGURED** | CLIs exist; additional chat/agent layers would overlap. |
| Avante/Copilot | **SKIP — DUPLICATE** | Would introduce overlapping AI UI, keymaps, and credentials. |

## Installed and retained integrations

| Plugin | Purpose | Load condition | Dependencies | Validation |
| --- | --- | --- | --- | --- |
| csvview.nvim | Delimited-file virtual columns | CSV/TSV, command, `<leader>cv` | Neovim 0.10+ | Source immutability, semicolon detection, and 10,000-row smoke passed |
| Diffview+ | Git diff and history inspection | Diffview command or `<leader>gv…` | Git, plenary | Open/close and command load passed |
| Octo | GitHub issues and PRs | `:Octo`, Octo URI, GitHub keys | Authenticated `gh`, Telescope | Health/load/auth checks passed; no Projects-v2 scope warning |
| Aerial | Persistent symbol outline | LazyFile or symbol keys | LSP/Tree-sitter | Outline toggle and navigation maps passed |
| TreeSJ | Syntax split/join | command or `<leader>cj` | Tree-sitter parsers | Lua split/join smoke passed |
| smart-splits | Split/tmux navigation | first navigation/resize key | tmux optional | Module and eight mappings passed |
| Yanky | Yank ring | LazyFile/yank keys | SQLite not required; Telescope picker | Module and relocated history map passed |
| Dial | Semantic increment/decrement | increment keys | none beyond Neovim | Effective keymaps/config groups passed |
| Undotree | Visual undo history | command or `<leader>uu` | persistent undo enabled | Open/close runtime smoke passed |
| SchemaStore | JSON schema catalog | jsonls startup | JSON LazyVim extra | Extra and lock entry verified |
| nvim-colorizer | Color feedback | selected filetype, command, `<leader>uH` | none | Restricted opts and command load passed |
| Obsidian | Vault notes/backlinks/dailies | vault Markdown or `:Obsidian` | detected vault, Telescope | Vault-only and non-vault isolation passed |
| Kulala | HTTP/REST requests | HTTP/REST filetype or request key | curl, project-local Kulala backend | Public no-secret HTTP 200 request passed |
| Overseer | Project tasks | self-lazy command/UI | project tool when present | Harmless `true` task passed |
| CodeCompanion | AI actions/chat/inline | command or `<leader>a…` | optional Keychain credential | Compatible `^19.0.0` range; loaded-plugin health and graceful missing-secret load passed |

Task discovery uses Overseer's built-in npm, pnpm, bun, Make, Just, and Cargo
providers. A local provider adds `go test ./...` for Go roots and `pytest` only
when a Python project marker and a `pytest` executable both exist.

## Maintenance and compatibility evidence

Selections were checked against current official project documentation and
release/tag state:

- [LazyVim](https://www.lazyvim.org/) and
  [lazy.nvim](https://lazy.folke.io/) for extras, bootstrap, lazy loading,
  lockfiles, and checker behavior.
- [csvview.nvim](https://github.com/hat0uma/csvview.nvim),
  [Diffview+](https://github.com/dlyongemallo/diffview-plus.nvim),
  [Octo](https://github.com/pwntester/octo.nvim),
  [Aerial](https://github.com/stevearc/aerial.nvim),
  [TreeSJ](https://github.com/Wansmer/treesj),
  [smart-splits](https://github.com/mrjones2014/smart-splits.nvim),
  [Yanky](https://github.com/gbprod/yanky.nvim),
  [Dial](https://github.com/monaqa/dial.nvim), and
  [Undotree](https://github.com/mbbill/undotree).
- [SchemaStore](https://github.com/b0o/SchemaStore.nvim),
  [nvim-colorizer](https://github.com/catgoose/nvim-colorizer.lua),
  [Obsidian](https://github.com/obsidian-nvim/obsidian.nvim),
  [Kulala](https://github.com/mistweaverco/kulala.nvim),
  [Overseer](https://github.com/stevearc/overseer.nvim), and
  [CodeCompanion](https://github.com/olimorris/codecompanion.nvim).

All resolved revisions are committed in `lazy-lock.json`; stable release
ranges are used only for projects whose upstream release policy supports it.
CodeCompanion follows the upstream installation guidance with `^19.0.0`,
while the lockfile fixes the exact validated release commit.

## Final validation snapshot

- `Lazy! sync` and `Lazy! check` completed with explicit lazy.nvim task-error
  inspection.
- All 33 declared Tree-sitter parsers were current, and every shipped query
  compiled against its installed parser.
- The complete health inventory remained identical to baseline: 9 error lines
  and 15 warning lines, all from pre-existing optional provider and
  terminal/image checks. Scoped Lazy, LSP, Tree-sitter, and loaded
  CodeCompanion health reports contained no errors.
- The regression suite, side-effect-free updater dry-run, concurrent-session
  rejection, runtime/health rollback simulations, parser realignment
  simulation, and runtime smoke suite passed.
- Seven alternating, like-for-like hardening samples had a 31.823 ms median,
  versus the 31.148 ms production-upgrade baseline: +0.675 ms (2.2%).
- The final Neovim Git subtree and `lazy-lock.json` were clean after sync.
