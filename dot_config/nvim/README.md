# Production LazyVim Configuration

This is a conservative LazyVim distribution for daily development. It keeps
LazyVim, Snacks, Telescope, blink.cmp, Noice, Oil, Gitsigns, LazyGit,
render-markdown, table-nvim, and CodeCompanion as the core experience, then
adds focused tools only where they provide a distinct workflow.

The live path, `~/.config/nvim`, is a symlink to this directory in the
`star-setup` repository. The complete pre-upgrade backup is:

```text
/Users/sam/.config/nvim.backup.20260725-023926
```

## Architecture

```text
init.lua                         lazy.nvim bootstrap
lazyvim.json                     authoritative LazyVim extras
lazy-lock.json                   reproducible plugin revisions
lua/config/                      options, keymaps, startup, and safe updates
lua/plugins/                     small plugin specs grouped by workflow
lua/overseer/template/user/      project-aware task discovery
scripts/                         verified updater and parser validation
tests/                           specification, policy, rollback, and runtime tests
docs/                            audit, keymaps, and operator runbooks
```

`lazyvim.json` owns the selected AI, editing, navigation, language, testing,
and dotfile extras. Snacks is the general picker; Telescope remains available
for the saved-theme workflow. Custom specs extend the extras instead of copying
their configuration. Heavy integrations use commands, keys, filetypes, or
LazyVim events as load boundaries.

## Selected workflows

| Area | Selected tools |
| --- | --- |
| Structured data | csvview.nvim; JSON LSP with SchemaStore |
| Git inspection | Diffview+ |
| GitHub collaboration | Octo |
| Git operations | Existing LazyGit |
| Structure/navigation | Aerial, TreeSJ, smart-splits |
| Editing | Yanky, Dial, Undotree |
| Markdown/notes | Existing render-markdown and table-nvim; vault-only Obsidian |
| HTTP requests | Kulala |
| Tasks | Overseer with project-aware Go/Python providers |
| AI | CodeCompanion, Claude Code integration, Copilot completion |
| UI | Snacks/Noice; restricted Colorizer; Tailwind-only mini.hipatterns |
| Testing | Neotest core; language adapters must be selected separately |

The detailed selection and rejection record is in
[Plugin Audit](docs/plugin-audit.md). See [Keymaps](docs/keymaps.md) for the
complete workflow reference.

## Installation and updates

On startup, lazy.nvim bootstraps from its stable branch if missing, and
declared missing plugins install automatically. lazy.nvim performs a
non-blocking update-availability check at most once every 24 hours.

Verified updates use a separate policy:

- a manual update is queued with `<leader>pu` or `:LazySafeUpdate`;
- an automatic update is considered no more than once every seven days;
- updates run only after the initiating interactive Neovim process exits and
  no other Neovim session is active;
- a clean Neovim Git subtree, valid lockfile, full backup, and idle Lazy
  process are required;
- every run snapshots `lazy-lock.json`, validates current lazy.nvim
  diagnostics and plugin tasks, installs and verifies all declared Tree-sitter
  parsers, runs specification and runtime smoke tests plus core and
  CodeCompanion health checks, and restores the previous lockfile, plugin
  revisions, and matching parsers on failure;
- a successful update leaves `lazy-lock.json` modified for review. That dirty
  Neovim subtree deliberately prevents another automatic update until the
  lockfile change is committed or reverted.

Use `:LazySafeUpdateStatus` or `<leader>ps` for the latest result, and
`:LazySafeUpdateCancel` to cancel an update queued for exit. Built-in `:Lazy`,
`:Lazy sync`, `:Lazy update`, `:Lazy check`, and `:Lazy restore` remain
available. The safe wrapper is preferred for updates.

See [Safe Updates and Rollback](docs/update-and-rollback.md) for state paths,
side-effect-free dry-run behavior, logs, disabling automation, and recovery.

## Colorschemes

**Space u C** opens the existing Telescope colorscheme picker with live preview.
Search for `kanagawa-wave`, move through the results to preview, and press Enter
to apply and save it for future Neovim sessions. **Ctrl-c** cancels and restores
the previous theme without saving the preview; Esc enters normal
mode in Telescope, where a second Esc closes it. Compare with `tokyonight-moon`
and `catppuccin-mocha` through the same picker.

The last theme confirmed with Enter becomes the startup default. The preference
is saved in `stdpath("state")/colorscheme.json`, outside the tracked configuration.
With multiple Neovim windows, the last confirmed selection wins; closing an older
window does not overwrite it. `:colorscheme` changes remain temporary.
Kanagawa Wave (`kanagawa-wave`) is the fallback when no saved theme is available.

Kanagawa uses upstream defaults: Wave,
opaque backgrounds, undercurl and terminal colors enabled, compilation disabled.
Lazy.nvim owns installation and updates; no terminal appearance settings change.

Use the same picker to change your saved theme again; no configuration edit is
needed. Existing Neovim sessions need one restart to load this saving behavior.

## Notes

The existing vault is `~/Obsidian/AI Projects`. New notes go into `00-inbox`,
dailies stay in `Daily Notes`, and images stay in `+`. Existing notes are never
moved. Set `NVIM_NOTES_DIR` before starting Neovim to choose another vault; on a
machine without an existing Obsidian vault, the fallback is `~/notes`.

Press **Space o i**, type an idea, and press Enter. It appends immediately to
`00-inbox/YYYY-MM-DD-ideas.md` and returns to your current buffer. Captures include
a timestamp and preserve Unicode and multiline pasted text. If the capture log
has unsaved edits in this Neovim session, the idea goes into a separate inbox file.
A failed write keeps the input in a recovery buffer and reports its buffer number.

Use **Space o n** for a titled note, **Space o d** for today, **Space o f** to find
notes, and **Space o s** to search their contents. **Space o t** creates a note
from a template. Five starter templates live in `templates/`: idea, note, project,
meeting, and daily. The tracked originals are in `templates/notes/` under this
configuration; initial setup copies missing templates and preserves edited copies.

Type `[[` for note completion. Enter follows a link or toggles a checkbox;
**Space o b** shows backlinks and **Space o l** lists links. **Space o p** pastes a
clipboard image into the attachment folder with a relative Markdown link.
`:lua require("obsidian.actions").add_attachment()` can import an image file.

**Space u m** toggles rendered Markdown; insert mode and the current cursor region
show raw syntax. **Space c p** toggles browser preview. **Space c s** opens Aerial,
and `[a` / `]a` move between headings. Notes are formatted explicitly with
**Space c f**, so saving a capture does not reflow it. **Space n** still opens
notification history. See [Keymaps](docs/keymaps.md) for the complete Notes table.

Obsidian owns vault links, completion, tags, daily notes, and templates.
`render-markdown` owns presentation; table-nvim owns table editing; Snacks owns
note pickers and input; Aerial owns the outline. Obsidian's language server runs
inside the vault and Marksman runs on other Markdown files. Frontmatter is set by
templates and is not rewritten automatically on existing notes.

Homebrew owns `marksman`, `markdownlint-cli2`, `markdown-toc`, and `pngpaste`;
`install-stars.sh` installs them and the existing `update-all` Homebrew section
updates them. Mason is excluded from those packages. Existing npm-global Prettier
and Homebrew ImageMagick remain in use. Prettier is installed under `/opt/homebrew`,
outside update-all's managed npm CLI inventory; its existing maintenance gap is
separate from the four new tools above. Lazy.nvim owns all editor plugins and the preview
plugin's bundled executable. The preview build waits for its download and verifies
the executable. No separate updater is needed.

Snacks supports images in direct Ghostty; visual rendering on this machine still
needs verification. Inline images are disabled when `HERDR_ENV=1` because
passthrough has not been verified; image files, Markdown links, and browser preview
still work. Clipboard image paste needs `pngpaste`. No Obsidian desktop process or
account is required.

Run `./tests/run.sh all` for deterministic tests and `./tests/notes-runtime.sh`
for an end-to-end test using installed plugins and a disposable vault. Architecture
and maintenance decisions are retained in Hindsight bank `coding-agent::star-setup`;
private note contents are excluded.

### Beginner / casual note-taking

Start with **Space o h** (Notes Home) or **Space o ?** (help). In a menu,
type to filter, move with the arrow keys, and press Enter to choose. Esc cancels.
The help window is read-only; `q` or Esc closes it.

1. **Create:** press **Space o n**, enter a title, then press Enter.
2. **Write:** press `i` to type or `o` to add a line below. Press Esc to stop typing.
   Use `u` to undo and Ctrl-r to redo.
3. **Leave:** existing writable Markdown files inside the vault auto-save when you
   leave insert mode, change buffers, or move focus out of Neovim. New notes made
   with Obsidian already have a file; a manually named new buffer needs `:w` once.
   Unnamed, read-only, and outside-vault buffers do not auto-save. An external disk
   change pauses autosave and warns once; review it with `:checktime` before saving.

For a passing thought, **Space o i** saves an idea immediately without leaving
your current buffer. **Space o d** opens today. **Space o f** finds a note by name;
**Space o s** searches its text. Type `[[` to complete a note link, press Enter in
normal mode to follow it, and use **Space o b** for backlinks.

Use `- ` for a bullet, `1. ` for a numbered item, or `- [ ] ` for a task. Enter
continues the list and starts new tasks unchecked. Enter on an empty item ends
the list. **Space o x** toggles a task between unchecked and checked; it leaves
ordinary paragraphs alone. List continuation is local to vault notes and skips
code blocks and metadata.

**Space o m** formats the current line: heading, bold, italic, strikethrough,
inline code, bullet, number, task, quote, callout, code block, Markdown link, or
wiki link. Table inserts below the line through table-nvim. This is a line menu,
so select-text formatting is intentionally omitted. Normal undo works. **Space c f**
still formats the whole file when you ask for it; autosave does not reflow prose.

Markdown rendering is on by default. Insert mode shows syntax; **Space u m**
toggles rendering. Frontmatter opens folded as “Properties”; **Space o v** reveals
or folds it again. Metadata remains editable and searchable. **Space o z** toggles
Snacks focus mode, hiding line numbers and centering the writing area. Toggling it
off restores the layout; opening a coding buffer also exits this note focus view.
**Space c p** opens browser preview and **Space c s** opens the heading outline.

Automatic markdownlint style diagnostics are skipped only in the personal vault.
Project Markdown keeps its normal linting, formatting, and Marksman support.
`:NotesLint` checks style explicitly in any Markdown buffer. Plugin errors and
language-server diagnostics remain visible.

## Credentials and privacy

No credentials are stored in this repository. Octo uses the authenticated
`gh` CLI. Projects v2 defaults are disabled because the core issue, PR, and
review workflows do not justify requesting the additional `read:project`
scope. CodeCompanion reads `ANTHROPIC_API_KEY` from the macOS Keychain only
when an Anthropic request is made. Kulala session restoration is disabled
because HTTP responses can contain private data.

Claude Code and Copilot use their own authentication. Their extras do not copy
CodeCompanion's credential or change agent permissions. Copilot can send buffer
context when its completion integration is active; disable its extra if that
is not appropriate for a workspace. Validation does not make an AI request or
launch a Claude session.

To add the optional CodeCompanion credential:

```bash
security add-generic-password -a "$(id -un)" -s ANTHROPIC_API_KEY -w
```

The command prompts for the value, avoiding a secret in shell history.

## Validation

Run the deterministic regression suite from this directory:

```bash
./tests/run.sh all
sh ./tests/review-runtime.sh
sh ./tests/colorscheme-runtime.sh
nvim --headless "+Lazy! sync" +qa
nvim --headless "+Lazy! check" +qa
nvim --headless "+checkhealth" +qa
nvim --headless "+lua require('config.lazy_validation').run_runtime_smoke(vim.fn.stdpath('config') .. '/tests/runtime_smoke.lua')" +qa
```

The runtime smoke test creates only temporary Markdown and CSV files. It
checks that CsvView never modifies source data, that Obsidian does not load
outside a vault, that TreeSJ can split/join syntax, that selected plugins load
on demand, and that Overseer can execute a harmless task.

`review-runtime.sh` checks the resolved plugin set against already-installed
locked revisions, effective shortcuts, safe buffer deletion, and theme
preview/confirmation/restart. It isolates state and cache, disables installs
and background maintenance, and does not activate AI clients. It fails if a
required plugin is missing rather than installing it.

CodeCompanion is intentionally optional, so load it before invoking its
plugin-specific health provider:

```bash
nvim --headless \
  "+lua require('lazy').load({ plugins = { 'codecompanion.nvim' } })" \
  "+checkhealth codecompanion" +qa
```

## Maintenance

To add a plugin safely:

1. Check for a LazyVim extra or existing Snacks/mini/Noice/blink capability.
2. Confirm current upstream maintenance, Neovim compatibility, dependencies,
   and security guidance.
3. Add one focused spec under `lua/plugins/` with `opts` and a real load
   boundary (`cmd`, `event`, `ft`, or `keys`).
4. Add descriptive, conflict-checked mappings and regression assertions.
5. Run the full validation suite and review the lockfile diff.

To disable a plugin without deleting its history, add a small override:

```lua
return {
  { "owner/plugin.nvim", enabled = false },
}
```

Place it under `lua/plugins/`, run `:Lazy sync`, and remove the override to
restore the plugin. Do not hand-edit lockfile entries.

For the earlier Markdown table workflow, see
[Markdown Table Workflow](docs/markdown-tables.md). The broader inherited
LazyVim reference remains in [Neovim Cheat Sheet](docs/nvim-cheatsheet.md).
