-- Picker (decided: Telescope as the primary fuzzy picker).
return {
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    keys = {
      { '<leader>ff', '<cmd>Telescope find_files<CR>', desc = 'Find files' },
      { '<leader>fg', '<cmd>Telescope live_grep<CR>', desc = 'Live grep' },
      { '<leader>fb', '<cmd>Telescope buffers<CR>', desc = 'Buffers' },
      { '<leader>fh', '<cmd>Telescope help_tags<CR>', desc = 'Help tags' },
      { '<leader>fd', '<cmd>Telescope diagnostics<CR>', desc = 'Diagnostics' },
      { '<leader>fr', '<cmd>Telescope oldfiles<CR>', desc = 'Recent files' },
      { '<leader><space>', '<cmd>Telescope find_files<CR>', desc = 'Find files' },
    },
    config = function()
      require('telescope').setup({})
      pcall(require('telescope').load_extension, 'fzf')
    end,
  },
}
