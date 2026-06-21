return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      {
        'mason-org/mason-lspconfig.nvim',
        opts = {
          -- mason-lspconfig v2 auto-installs these and auto-enables via vim.lsp.enable().
          ensure_installed = { 'lua_ls', 'ts_ls', 'pyright', 'bashls', 'jsonls', 'yamlls', 'gopls' },
        },
      },
      'saghen/blink.cmp',
    },
    config = function()
      -- Global LSP defaults (capabilities from blink.cmp) for every server.
      vim.lsp.config('*', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      })
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            diagnostics = { globals = { 'vim' } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      -- Buffer-local keymaps when a server attaches.
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
          local function m(keys, fn, desc)
            vim.keymap.set('n', keys, fn, { buffer = ev.buf, desc = 'LSP: ' .. desc })
          end
          m('gd', vim.lsp.buf.definition, 'Go to definition')
          m('gD', vim.lsp.buf.declaration, 'Go to declaration')
          m('gr', vim.lsp.buf.references, 'References')
          m('gi', vim.lsp.buf.implementation, 'Implementation')
          m('K', vim.lsp.buf.hover, 'Hover')
          m('<leader>rn', vim.lsp.buf.rename, 'Rename')
          m('<leader>ca', vim.lsp.buf.code_action, 'Code action')
        end,
      })
    end,
  },
}
