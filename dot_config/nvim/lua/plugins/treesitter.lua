-- nvim-treesitter MAIN branch (the rewrite; requires Neovim 0.12+).
return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').install({
        'lua', 'vim', 'vimdoc', 'query', 'bash', 'python',
        'javascript', 'typescript', 'tsx', 'json', 'yaml', 'toml',
        'markdown', 'markdown_inline', 'html', 'css', 'go', 'rust', 'c',
        'diff', 'gitcommit', 'git_rebase',
      })
      -- Start highlighting whenever a parser is available for the buffer.
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if lang and pcall(vim.treesitter.get_parser, ev.buf, lang) then
            pcall(vim.treesitter.start, ev.buf, lang)
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
