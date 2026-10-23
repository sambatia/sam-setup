# LazyVim Markdown Tables Implementation Plan

> **For Codex:** Implement and verify this plan task-by-task.

**Goal:** Add a focused, portable Markdown table editing workflow to the existing LazyVim configuration.

**Architecture:** Load a single table editor only in Markdown buffers. Preserve LazyVim's existing Tree-sitter setup, completion mappings, and optional Markdown tooling; table creation, navigation, structural changes, and automatic alignment are all handled by the selected editor.

**Tech Stack:** Neovim 0.12.4, LazyVim 16.0.0, lazy.nvim, nvim-treesitter, SCJangra/table-nvim.

---

### Task 1: Add a Markdown-only plugin specification

**Files:**
- Create: `lua/plugins/markdown-tables.lua`
- Modify: `lazy-lock.json` (only through `:Lazy sync`)

**Step 1:** Confirm that `nvim-treesitter` and the Markdown parsers already exist.

**Step 2:** Add the minimal `table-nvim` spec with Markdown-only filetypes and its documented options.

**Step 3:** Keep `<Tab>` and `<S-Tab>` context-aware; add only buffer-local plugin mappings under `<leader>t`.

**Step 4:** Parse the Lua file before synchronization.

### Task 2: Synchronize and test the plugin

**Files:**
- Modify: `lazy-lock.json`
- Test: `/tmp/lazyvim-markdown-table-test.md`

**Step 1:** Run `:Lazy! sync` to install only the new plugin and update its lock entry.

**Step 2:** Open a Markdown buffer and assert the plugin is loaded and mappings are buffer-local.

**Step 3:** Exercise creation, cell navigation, row and column edits, alignment, Unicode, escaped pipes, undo/redo, save/reopen, and a fresh Neovim process.

### Task 3: Document daily use and recovery

**Files:**
- Create: `docs/markdown-tables.md`

**Step 1:** Document the selected plugin, mapping table, Markdown example, lazy-loading behavior, troubleshooting, update procedure, removal, and the timestamped lockfile backup.

**Step 2:** Verify the documentation paths and final diff.
