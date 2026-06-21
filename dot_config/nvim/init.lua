-- Neovim config — Lazy.nvim stack (consolidated toolset, 2026-06-21)
-- Leader keys must be set before lazy.nvim loads so plugin keymaps register correctly.
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

require('config.options')
require('config.keymaps')
require('config.lazy')
