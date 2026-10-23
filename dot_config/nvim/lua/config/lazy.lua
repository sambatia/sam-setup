-- LazyVim bootstrap.
-- Migrated 2026-07-09 from a hand-built lazy.nvim stack. Prior config is in git
-- history (branch: lazyvim-migration, parent commit) and lazy-lock.json.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim core, and its default plugin set.
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- Extras are managed in lazyvim.json so :LazyExtras remains authoritative.
    -- Workflow overrides preserve CodeCompanion shortcuts alongside the
    -- selected AI extras and retain the persistent Telescope theme picker.

    -- Personal overrides and additions. Loaded after LazyVim so they win.
    { import = "plugins" },
  },
  defaults = {
    -- Only enable custom plugins when they are added, so LazyVim's own specs
    -- keep their lazy-loading behavior.
    lazy = false,
    -- Always use the latest git commit for plugins not pinned by LazyVim.
    version = false,
  },
  install = {
    missing = true,
    colorscheme = { "tokyonight", "habamax" },
  },
  checker = {
    enabled = true,
    notify = true,
    frequency = 86400,
  },
  change_detection = { notify = false },
  rocks = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
