return {
  -- File explorer (decided: Oil — buffer-as-filesystem; NOT neo-tree)
  {
    'stevearc/oil.nvim',
    lazy = false,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { view_options = { show_hidden = true } },
    keys = { { '-', '<cmd>Oil<CR>', desc = 'Open parent dir (Oil)' } },
  },

  -- Quick file navigation
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local h = require('harpoon')
      h:setup()
      vim.keymap.set('n', '<leader>ha', function() h:list():add() end, { desc = 'Harpoon add' })
      vim.keymap.set('n', '<C-e>', function() h.ui:toggle_quick_menu(h:list()) end, { desc = 'Harpoon menu' })
      for i = 1, 4 do
        vim.keymap.set('n', '<leader>' .. i, function() h:list():select(i) end, { desc = 'Harpoon ' .. i })
      end
    end,
  },

  -- Session persistence
  { 'folke/persistence.nvim', event = 'BufReadPre', opts = {} },
}
