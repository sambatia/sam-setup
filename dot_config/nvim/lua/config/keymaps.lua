-- Keymaps. Loaded by LazyVim on VeryLazy (after lazyvim.config.keymaps).
--
-- Already provided by LazyVim, equal or better — deliberately NOT redefined:
--   <Esc>        clear search highlight
--   <C-s>        save file            (pre-migration used <leader>w)
--   <leader>qq   quit all             (pre-migration used <leader>q)
--   <leader>e    file explorer        (do NOT rebind: this is a LazyVim default)
--   <leader>cd   line diagnostics     (pre-migration used <leader>e for this)
--   <C-h/j/k/l>  window navigation
--   [d / ]d      prev/next diagnostic (LazyVim's honor v:count and severity)
--   ]e / [e      next/prev ERROR      (new; better than the old config)
--   ]w / [w      next/prev WARNING    (new)
--
-- The pre-migration config bound <leader>w, <leader>q and <leader>e as direct
-- commands. Under LazyVim those are which-key *prefixes* (windows, quit, and
-- the explorer). Rebinding them would shadow whole groups, so the LazyVim
-- equivalents are used instead. Nothing is lost — only relearned:
--
--   save          <leader>w  ->  <C-s>
--   quit          <leader>q  ->  <leader>qq
--   diag float    <leader>e  ->  <leader>cd
--
-- LazyVim's own keymaps use LazyVim.safe_keymap_set (internal). User config
-- should use vim.keymap.set directly, which is what we do below.

-- Dashboard (start screen / "main menu").
-- Use Snacks' public API instead of depending on a command alias.
vim.keymap.set("n", "<leader>fd", function()
  Snacks.dashboard()
end, { desc = "Dashboard (Home)" })

-- Close buffer, then show the dashboard once no listed buffers remain.
-- <leader>bd keeps its LazyVim default (delete buffer); this only adds the
-- fallback to the dashboard when you've closed your last file.
vim.keymap.set("n", "<leader>bh", function()
  local buf = vim.api.nvim_get_current_buf()
  local last = #vim.fn.getbufinfo({ buflisted = 1 }) <= 1
  -- Snacks owns save/discard/cancel confirmation; never force deletion.
  Snacks.bufdelete()
  if last and (not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted) then
    Snacks.dashboard()
  end
end, { desc = "Delete Buffer / Dashboard" })

-- Nothing else to add yet. Add personal keymaps here as they come up; anything
-- that collides with a LazyVim default is a deliberate choice, not an accident.
