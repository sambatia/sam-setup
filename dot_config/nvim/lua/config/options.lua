-- Options. Loaded by LazyVim on VeryLazy (after lazyvim.config.options).
--
-- LazyVim already sets, identically to the pre-migration config:
--   number, relativenumber, mouse=a, showmode=false, clipboard=unnamedplus,
--   undofile, ignorecase, smartcase, signcolumn=yes, updatetime, timeoutlen,
--   splitright, splitbelow, list, inccommand=split, cursorline, scrolloff=8,
--   expandtab, shiftwidth=2, tabstop=2, smartindent, termguicolors, confirm
-- Those are intentionally NOT repeated here.
--
-- Only genuine deltas from LazyVim's defaults live below.

local o = vim.opt

-- LazyVim doesn't set this; carried over from the pre-migration config.
o.breakindent = true

-- LazyVim's listchars use different glyphs; keep the previous ones.
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Neovim 0.11+ global window border. LazyVim leaves this at the default.
o.winborder = "rounded"
