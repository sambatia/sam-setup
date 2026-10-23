# LazyVim Production Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a validated, lazy-loaded LazyVim configuration with focused data, Git, navigation, editing, Obsidian, request, task, AI, and rollback-safe plugin update workflows.

**Architecture:** Record supported LazyVim integrations in `lazyvim.json`, keep custom plugins in focused category specifications, and place update decisions in a testable Lua module backed by a defensive shell updater. Perform installation and integration tests in isolated XDG directories before merging into the live symlinked configuration.

**Tech Stack:** Neovim 0.12.4, LazyVim 16.0.0, lazy.nvim 11.17.5, Lua, POSIX-compatible zsh/sh, Git, Homebrew tools, GitHub CLI, and headless Neovim integration tests.

---

### Task 1: Add the configuration regression harness

**Files:**
- Create: `dotfiles/nvim/tests/helpers.lua`
- Create: `dotfiles/nvim/tests/plugin_spec.lua`
- Create: `dotfiles/nvim/tests/update_policy_spec.lua`
- Create: `dotfiles/nvim/tests/run.sh`

**Step 1: Write failing specification assertions**

Add assertions that load the real Lazy configuration and require:

- the approved plugin names and LazyVim extras;
- no Neogit, Illuminate, Fidget, or nvim-bqf plugin;
- command/filetype/key lazy-loading on custom plugins;
- the selected keymaps and descriptions;
- CodeCompanion `interactions` with no `strategies`;
- daily checker frequency and explicit missing-plugin installation;
- pure update-policy functions for elapsed intervals, UI/headless state, Git
  cleanliness, backup presence, and lock state.

**Step 2: Run the tests to verify they fail**

Run:

```bash
cd dotfiles/nvim
./tests/run.sh
```

Expected: failure because the approved plugin specifications and
`config.update_policy` do not exist.

**Step 3: Add only reusable test helpers and the runner**

The runner must:

- create temporary state/cache/data directories;
- point `XDG_CONFIG_HOME` at the worktree's `dotfiles` directory;
- preserve and report the real exit code;
- remove only its own validated temporary directory;
- run both pure-policy and loaded-spec assertions.

**Step 4: Re-run the tests and preserve the expected RED result**

Run `./tests/run.sh`.

Expected: assertions run correctly and fail on missing production behavior,
not on runner errors.

**Step 5: Commit**

```bash
git add dotfiles/nvim/tests
git commit -m "test(nvim): add production configuration regression harness"
```

### Task 2: Normalize LazyVim extras and modernize CodeCompanion

**Files:**
- Modify: `dotfiles/nvim/lazyvim.json`
- Modify: `dotfiles/nvim/lua/config/lazy.lua`
- Modify: `dotfiles/nvim/lua/plugins/ai.lua`
- Modify: `dotfiles/nvim/lua/plugins/overrides.lua`

**Step 1: Extend the failing tests**

Assert the authoritative extras list contains:

```text
lazyvim.plugins.extras.coding.yanky
lazyvim.plugins.extras.editor.aerial
lazyvim.plugins.extras.editor.dial
lazyvim.plugins.extras.editor.overseer
lazyvim.plugins.extras.editor.telescope
lazyvim.plugins.extras.lang.json
lazyvim.plugins.extras.util.octo
```

Assert the old manual Telescope import is absent and CodeCompanion uses:

```lua
interactions = {
  chat = { adapter = "anthropic" },
  inline = { adapter = "anthropic" },
  cmd = { adapter = "anthropic" },
}
```

**Step 2: Run the focused assertions and verify RED**

Run `./tests/run.sh plugin_spec`.

Expected: extras and CodeCompanion migration assertions fail.

**Step 3: Implement the minimum changes**

- Put the sorted extras in `lazyvim.json`.
- Remove the duplicate manual Telescope import.
- Set `install.missing = true`.
- Configure the lazy checker for `enabled = true`, `notify = true`, and
  `frequency = 86400`.
- Rename CodeCompanion `strategies` to `interactions`.
- Remove the manual bare `jsonls = {}` entry so the JSON extra owns its
  SchemaStore-aware setup; preserve all other LSP servers.

**Step 4: Verify GREEN**

Run:

```bash
./tests/run.sh plugin_spec
nvim --headless +qa
```

Expected: focused assertions and startup pass.

**Step 5: Commit**

```bash
git add dotfiles/nvim/lazyvim.json dotfiles/nvim/lua/config/lazy.lua \
  dotfiles/nvim/lua/plugins/ai.lua dotfiles/nvim/lua/plugins/overrides.lua
git commit -m "refactor(nvim): normalize extras and modernize CodeCompanion"
```

### Task 3: Add data, editing, navigation, and UI plugins

**Files:**
- Create: `dotfiles/nvim/lua/plugins/data.lua`
- Create: `dotfiles/nvim/lua/plugins/editing.lua`
- Create: `dotfiles/nvim/lua/plugins/navigation.lua`
- Create: `dotfiles/nvim/lua/plugins/ui.lua`
- Modify: `dotfiles/nvim/tests/plugin_spec.lua`

**Step 1: Add failing behavior assertions**

Require:

- csvview commands, CSV/TSV filetypes, asynchronous parser limits,
  comma/tab/semicolon detection, and `<leader>cv`;
- TreeSJ command loading, no default mappings, and `<leader>cj`;
- Undotree command loading and `<leader>uu`;
- smart-splits mappings for `<C-h/j/k/l>` and `<M-h/j/k/l>`;
- Aerial `[a`/`]a` navigation while retaining the official extra toggle;
- Yanky history on `<leader>sy` with the exact `<leader>p` mapping removed;
- canonical `catgoose/nvim-colorizer.lua`, selected filetypes, lazy scheduling,
  no LSP parser overlap, and `<leader>uH`.

**Step 2: Run the tests and verify RED**

Run `./tests/run.sh plugin_spec`.

Expected: the new plugin and mapping assertions fail.

**Step 3: Implement the minimum plugin specifications**

Use these boundaries:

```lua
cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle", "CsvViewInfo" }
ft = { "csv", "tsv" }
cmd = { "TSJToggle", "TSJSplit", "TSJJoin" }
cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeHide" }
event = "VeryLazy" -- smart-splits
ft = { "css", "scss", "html", "javascript", "javascriptreact",
       "typescript", "typescriptreact", "lua" } -- colorizer
```

Configure csvview's parser with `async_chunksize = 25`,
`max_lookahead = 50`, explicit CSV/TSV mappings, and comma/tab/semicolon
fallbacks. Configure TreeSJ with syntax checks and a 120-column join limit.
Configure colorizer using the current structured `options` API and disable its
LSP parser to avoid Neovim 0.12 document-color duplication.

**Step 4: Verify GREEN and parse all Lua**

Run:

```bash
./tests/run.sh plugin_spec
nvim --headless -c 'lua for _,f in ipairs(vim.fn.glob("lua/**/*.lua", true, true)) do assert(loadfile(f)) end' +qa
```

Expected: all assertions and Lua parsing pass.

**Step 5: Commit**

```bash
git add dotfiles/nvim/lua/plugins/{data,editing,navigation,ui}.lua \
  dotfiles/nvim/tests/plugin_spec.lua
git commit -m "feat(nvim): add focused data editing navigation and UI tools"
```

### Task 4: Add maintained Git and GitHub workflows

**Files:**
- Create: `dotfiles/nvim/lua/plugins/git.lua`
- Modify: `dotfiles/nvim/tests/plugin_spec.lua`

**Step 1: Add failing assertions**

Require:

- `dlyongemallo/diffview-plus.nvim`, stable release range, command loading,
  and `<leader>gdo/gdf/gdh/gdx`;
- no `sindrets/diffview.nvim`;
- Octo's official extra and lazy command/URI behavior;
- `<leader>gS` still describes Git stash;
- Octo search moved to `<leader>go`;
- no Neogit or separate browse/blame plugin.

**Step 2: Run the focused test and verify RED**

Run `./tests/run.sh plugin_spec`.

Expected: Git workflow assertions fail.

**Step 3: Implement the Git specification**

Use `version = "*"` for diffview+ v0 releases, depend on the existing icon
provider, and keep defaults except for enhanced diff highlighting and
diagnostics disabled in diff/merge buffers. Override Octo's conflicting
`<leader>gS` key to false and add `<leader>go` for `:Octo search`.

**Step 4: Verify GREEN**

Run `./tests/run.sh plugin_spec`.

Expected: all Git assertions pass.

**Step 5: Commit**

```bash
git add dotfiles/nvim/lua/plugins/git.lua dotfiles/nvim/tests/plugin_spec.lua
git commit -m "feat(nvim): add diff inspection and GitHub workflows"
```

### Task 5: Add vault-scoped Obsidian and developer task workflows

**Files:**
- Create: `dotfiles/nvim/lua/plugins/markdown.lua`
- Create: `dotfiles/nvim/lua/plugins/tasks.lua`
- Create: `dotfiles/nvim/lua/overseer/template/user/project_tasks.lua`
- Modify: `dotfiles/nvim/tests/plugin_spec.lua`

**Step 1: Add failing assertions**

Require:

- `obsidian-nvim/obsidian.nvim` with `version = "*"`;
- the detected workspace and vault-scoped read/new-file events;
- legacy commands disabled, daily notes configured, no invented templates
  folder, and Obsidian mappings under `<leader>o`;
- Kulala HTTP/REST loading and buffer-specific request mappings;
- Overseer global mappings under `<leader>r`;
- tool-aware custom tasks for pnpm/bun/npm, make, just, pytest,
  `go test`, and cargo;
- LazyDocker launched through Snacks only when executable.

**Step 2: Run and verify RED**

Run `./tests/run.sh plugin_spec`.

Expected: Markdown/task assertions fail.

**Step 3: Implement the workflow specifications**

Build the Obsidian autocmd patterns with escaped absolute paths, keep commands
available for explicit loading, and let its built-in LSP feed blink.cmp.
Configure Kulala with default global mappings disabled and four buffer-local
keys. Extend the official Overseer extra by disabling its `<leader>o*` keys,
adding `<leader>rr/ra/rt`, and registering the custom provider. Each provider
candidate must have executable and project-root conditions.

**Step 4: Verify GREEN**

Run:

```bash
./tests/run.sh plugin_spec
nvim --headless +qa
```

Expected: assertions and startup pass.

**Step 5: Commit**

```bash
git add dotfiles/nvim/lua/plugins/{markdown,tasks}.lua \
  dotfiles/nvim/lua/overseer/template/user/project_tasks.lua \
  dotfiles/nvim/tests/plugin_spec.lua
git commit -m "feat(nvim): add vault requests and project task workflows"
```

### Task 6: Implement safe automatic updates and rollback

**Files:**
- Create: `dotfiles/nvim/lua/config/update_policy.lua`
- Create: `dotfiles/nvim/lua/plugins/updates.lua`
- Create: `dotfiles/nvim/scripts/safe-plugin-update.sh`
- Modify: `dotfiles/nvim/tests/update_policy_spec.lua`
- Modify: `dotfiles/nvim/tests/run.sh`

**Step 1: Complete the pure policy tests**

Test exact boundary cases:

- 86,399 versus 86,400 seconds for checks;
- six days versus seven days for updates;
- no UI/headless process;
- dirty config subtree;
- absent baseline backup;
- existing lock directory;
- malformed or absent lockfile;
- forced manual request.

**Step 2: Run and verify RED**

Run `./tests/run.sh update_policy_spec`.

Expected: missing module failure.

**Step 3: Implement the pure policy module**

Export decision functions without side effects, then add scheduling functions
that:

- use `stdpath("state") .. "/safe-plugin-updates"`;
- never schedule in a headless session;
- mark a pending automatic update only when every guard passes;
- spawn the updater detached on `VimLeavePre`;
- surface the previous result once on the next interactive startup.

**Step 4: Verify policy GREEN**

Run `./tests/run.sh update_policy_spec`.

Expected: every boundary assertion passes.

**Step 5: Add failing updater integration tests**

Use a temporary fake config repository and command shims to test:

- dry-run eligibility;
- atomic lock rejection;
- lockfile snapshot creation;
- successful result/log creation;
- simulated validation failure;
- restored lockfile content and restore invocation.

No test may read or write the live lockfile, data directory, or state directory.

**Step 6: Run and verify integration RED**

Run `./tests/run.sh updater_integration`.

Expected: failure because the shell updater is absent.

**Step 7: Implement the defensive updater**

The script must:

- use `set -eu`;
- resolve and validate explicit config/state paths;
- reject broad or unresolved paths;
- acquire a `mkdir` lock and remove it through a trap;
- check `git status --porcelain -- <config-subtree>`;
- validate `lazy-lock.json` with `jq`;
- snapshot the lockfile before update;
- run preflight startup, `Lazy! update`, `Lazy! sync`, specification checks,
  and scoped core health;
- restore the snapshot and run `Lazy! restore` on any failure;
- write timestamp/result files atomically;
- support `--dry-run`, `--manual`, and test-only injected command paths
  without weakening production defaults.

**Step 8: Verify GREEN and shell syntax**

Run:

```bash
./tests/run.sh updater_integration
zsh -n scripts/safe-plugin-update.sh
```

Expected: integration cases and syntax pass.

**Step 9: Add the Lazy commands and keymap**

Expose `:LazySafeUpdate`, `:LazySafeUpdateStatus`, and `<leader>pu`.
Register `<leader>p` as `plugins` in WhichKey. The safe update command queues
the same verified updater; it must not call raw update logic in-process.

**Step 10: Commit**

```bash
git add dotfiles/nvim/lua/config/update_policy.lua \
  dotfiles/nvim/lua/plugins/updates.lua \
  dotfiles/nvim/scripts/safe-plugin-update.sh dotfiles/nvim/tests
git commit -m "feat(nvim): add verified automatic updates and rollback"
```

### Task 7: Synchronize and validate in an isolated Neovim environment

**Files:**
- Modify: `dotfiles/nvim/lazy-lock.json`
- Modify as required by discovered compatibility issues: approved plugin files

**Step 1: Create explicit isolated XDG directories**

Use a unique `mktemp -d` directory and set:

```text
XDG_CONFIG_HOME=<worktree>/dotfiles
XDG_DATA_HOME=<temp>/data
XDG_STATE_HOME=<temp>/state
XDG_CACHE_HOME=<temp>/cache
```

**Step 2: Bootstrap and synchronize**

Run:

```bash
nvim --headless "+Lazy! sync" +qa
nvim --headless "+Lazy! check" +qa
```

Expected: clean exit codes and a complete isolated plugin installation.

**Step 3: Run scoped health and plugin health checks**

Run core health plus CodeCompanion, Obsidian, and Kulala health checks after
explicitly loading their plugins. Capture output and investigate every new
error.

**Step 4: Run functional integration tests**

Exercise:

- CSV toggle plus byte-for-byte source comparison;
- TreeSJ toggle on Lua, JSON, JavaScript, TypeScript, Python, and Markdown;
- Dial on numbers, dates, booleans, semantic versions, and Markdown tasks;
- Yanky yank/history/cycle;
- Undotree toggle;
- Aerial attach/toggle/navigation;
- Diffview+ open/history/close in the worktree repository;
- Octo command availability with authenticated `gh`;
- Obsidian load inside and non-load outside the vault;
- harmless Kulala request against `https://httpbin.org/get`, with no secrets;
- Overseer task discovery and a harmless task;
- CodeCompanion health without invoking a paid request.

**Step 5: Fix root causes and repeat**

Apply the systematic-debugging skill for any failure. Re-run the smallest
failing scope, then the complete regression suite.

**Step 6: Commit the resolved lockfile**

```bash
git add dotfiles/nvim/lazy-lock.json dotfiles/nvim/lua
git commit -m "chore(nvim): lock validated plugin versions"
```

### Task 8: Complete documentation

**Files:**
- Create: `dotfiles/nvim/README.md`
- Create: `dotfiles/nvim/docs/plugin-audit.md`
- Create: `dotfiles/nvim/docs/keymaps.md`
- Create: `dotfiles/nvim/docs/update-and-rollback.md`
- Modify: `dotfiles/nvim/docs/nvim-cheatsheet.md`

**Step 1: Write documentation checks**

Add simple assertions that all required documents exist and contain the backup
path, selected/rejected plugins, keymap namespaces, state/log paths, automatic
policy, manual commands, rollback flow, disable/add guidance, and credential
notes.

**Step 2: Run and verify RED**

Run `./tests/run.sh docs`.

Expected: required files/sections are missing.

**Step 3: Write the documentation**

Use the verified configuration as the source of truth. Clearly distinguish
headless checks from visually verified behavior and include upstream links.

**Step 4: Verify GREEN**

Run:

```bash
./tests/run.sh docs
git diff --check
```

Expected: documentation assertions and whitespace checks pass.

**Step 5: Commit**

```bash
git add dotfiles/nvim/README.md dotfiles/nvim/docs
git commit -m "docs(nvim): document plugins keymaps and recovery"
```

### Task 9: Format, review, merge, and validate the live configuration

**Files:**
- Modify mechanically: all changed Lua files

**Step 1: Install or run Stylua without changing global ownership**

Prefer an existing Homebrew/mise tool. If absent, use a temporary released
binary or `cargo install --root <temporary-dir> stylua` and record the version.
Do not install into the global Cargo or npm prefix.

**Step 2: Format and run the complete isolated suite**

Run:

```bash
stylua lua tests
./tests/run.sh
git diff --check
```

Expected: formatter, tests, and whitespace checks pass.

**Step 3: Measure isolated startup**

Run three startup samples, report the median, and compare it to the 28.828 ms
baseline. Investigate any material regression.

**Step 4: Inspect final scope and secrets**

Run:

```bash
git status --short
git diff <design-commit>..HEAD --stat
git diff <design-commit>..HEAD --check
```

Run repository secret hooks/scanners on the committed diff.

**Step 5: Request code review**

Use the requesting-code-review skill without delegation if subagents are
disabled: review requirements line by line, inspect every changed file, and
record issues. Fix all Critical and Important findings, then repeat the full
suite.

**Step 6: Merge verified commits into the live branch**

Fast-forward or merge the implementation branch into
`codex/lazyvim-production-upgrade-20260725` without touching unrelated working
tree files. Confirm the symlink now exposes the merged configuration.

**Step 7: Synchronize and validate live**

Run fresh:

```bash
nvim --headless "+Lazy! sync" +qa
nvim --headless "+Lazy! check" +qa
nvim --headless "+checkhealth" "+w! /tmp/nvim-health-after.txt" +qa
nvim --startuptime /tmp/nvim-startup-after.log +qa
```

Then run the complete regression suite against the live config, safe-updater
dry-run, lockfile rollback simulation in a temporary clone, Git status, and
secret checks.

**Step 8: Final verification and handoff**

Apply verification-before-completion. Report exact command results, changed
files, commits, branch, backup, performance, baseline versus final health,
remaining external credential actions, and that nothing was pushed.
