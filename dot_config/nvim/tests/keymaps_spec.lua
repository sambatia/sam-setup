local h = dofile(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "helpers.lua"))
vim.g.mapleader = " "
local shown, deleted, cancel = 0, 0, false
_G.Snacks = {
  dashboard = function()
    shown = shown + 1
  end,
  bufdelete = function()
    deleted = deleted + 1
    if cancel then
      return
    end
    local current = vim.api.nvim_get_current_buf()
    local others = vim.tbl_filter(function(buf)
      return buf.bufnr ~= current
    end, vim.fn.getbufinfo({ buflisted = 1 }))
    vim.api.nvim_set_current_buf(others[1] and others[1].bufnr or vim.api.nvim_create_buf(true, false))
    vim.api.nvim_buf_delete(current, {})
  end,
}
dofile(vim.fs.joinpath(h.root, "lua/config/keymaps.lua"))
local close = assert(vim.fn.maparg("<leader>bh", "n", false, true).callback)
local dashboard = assert(vim.fn.maparg("<leader>fd", "n", false, true).callback)
local original = vim.api.nvim_get_current_buf()
dashboard()
assert(shown == 1 and deleted == 0, "dashboard shortcut must not delete a buffer")
close()
assert(deleted == 1, "last buffer must use the safe Snacks deletion path")
assert(
  not vim.api.nvim_buf_is_valid(original) or not vim.bo[original].buflisted,
  "last closed buffer must not remain listed"
)
assert(shown == 2, "closing the last buffer must open the dashboard")
h.pass("last-buffer shortcut deletes the buffer before showing the dashboard")

local first = vim.api.nvim_get_current_buf()
vim.api.nvim_create_buf(true, false)
close()
assert(
  deleted == 2 and (not vim.api.nvim_buf_is_valid(first) or not vim.bo[first].buflisted),
  "multiple-buffer close must delete the current buffer"
)
assert(shown == 2, "multiple-buffer close must not open a dashboard")
h.pass("multiple-buffer shortcut leaves other buffers available")

cancel = true
local unsaved = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(unsaved, 0, -1, false, { "unsaved work" })
close()
assert(deleted == 3, "unsaved buffer must still use the safe confirmation path")
assert(vim.api.nvim_get_current_buf() == unsaved and vim.bo[unsaved].modified, "cancel must preserve unsaved edits")
assert(shown == 2, "cancel must not replace the buffer with a dashboard")
h.pass("cancelled deletion preserves unsaved edits and the current view")
