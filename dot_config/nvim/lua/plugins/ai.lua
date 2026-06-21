-- AI assistant (decided: CodeCompanion — a single in-editor assistant, NOT Avante).
-- Uses the `anthropic` adapter; set ANTHROPIC_API_KEY in your env to enable it.
return {
  {
    'olimorris/codecompanion.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-treesitter/nvim-treesitter' },
    cmd = { 'CodeCompanion', 'CodeCompanionChat', 'CodeCompanionActions', 'CodeCompanionCmd' },
    keys = {
      { '<leader>aa', '<cmd>CodeCompanionActions<CR>', mode = { 'n', 'v' }, desc = 'CodeCompanion actions' },
      { '<leader>ac', '<cmd>CodeCompanionChat Toggle<CR>', mode = { 'n', 'v' }, desc = 'CodeCompanion chat' },
      { '<leader>ap', '<cmd>CodeCompanion<CR>', mode = { 'n', 'v' }, desc = 'CodeCompanion inline' },
    },
    opts = {
      strategies = {
        chat = { adapter = 'anthropic' },
        inline = { adapter = 'anthropic' },
        cmd = { adapter = 'anthropic' },
      },
    },
  },
}
