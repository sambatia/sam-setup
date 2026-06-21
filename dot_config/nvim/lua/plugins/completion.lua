return {
  -- Completion engine (decided: blink.cmp, pinned to v1 for stability — NOT nvim-cmp)
  {
    'saghen/blink.cmp',
    version = '1.*',
    event = 'InsertEnter',
    dependencies = { 'L3MON4D3/LuaSnip', 'rafamadriz/friendly-snippets' },
    opts = {
      keymap = { preset = 'default' },
      appearance = { nerd_font_variant = 'mono' },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      snippets = { preset = 'luasnip' },
      completion = { documentation = { auto_show = true, auto_show_delay_ms = 200 } },
      signature = { enabled = true },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
    opts_extend = { 'sources.default' },
  },
  {
    'L3MON4D3/LuaSnip',
    version = 'v2.*',
    dependencies = { 'rafamadriz/friendly-snippets' },
    config = function()
      require('luasnip.loaders.from_vscode').lazy_load()
    end,
  },
}
