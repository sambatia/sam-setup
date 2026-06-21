return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      on_attach = function(buf)
        local gs = require('gitsigns')
        local function m(keys, fn, desc)
          vim.keymap.set('n', keys, fn, { buffer = buf, desc = 'Git: ' .. desc })
        end
        m(']h', gs.next_hunk, 'Next hunk')
        m('[h', gs.prev_hunk, 'Prev hunk')
        m('<leader>hs', gs.stage_hunk, 'Stage hunk')
        m('<leader>hr', gs.reset_hunk, 'Reset hunk')
        m('<leader>hp', gs.preview_hunk, 'Preview hunk')
        m('<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
      end,
    },
  },
}
