return {
  -- Keymap discoverability
  { 'folke/which-key.nvim', event = 'VeryLazy', opts = { preset = 'helix' } },

  -- QoL suite: input (replaces archived dressing.nvim), notifier, picker, etc.
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      input = { enabled = true },
      notifier = { enabled = true },
      picker = { enabled = true },
      quickfile = { enabled = true },
      bigfile = { enabled = true },
      words = { enabled = true },
      indent = { enabled = true },
      scope = { enabled = true },
    },
  },

  -- Diagnostics / quickfix list
  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
    opts = {},
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', desc = 'Diagnostics (Trouble)' },
      { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Buffer diagnostics (Trouble)' },
      { '<leader>xq', '<cmd>Trouble qflist toggle<CR>', desc = 'Quickfix (Trouble)' },
    },
  },
}
