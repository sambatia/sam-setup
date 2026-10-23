local M = {}
local states = {}
local group = vim.api.nvim_create_augroup("notes_autosave", { clear = true })

local function stamp(buffer)
  local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(buffer))
  return stat and { stat.dev, stat.ino, stat.size, stat.mtime, stat.ctime } or nil
end

local function eligible(buffer)
  local bo = vim.bo[buffer]
  local path = vim.api.nvim_buf_get_name(buffer)
  return bo.filetype == "markdown"
    and bo.buftype == ""
    and bo.modifiable
    and not bo.readonly
    and path ~= ""
    and require("config.notes").contains(path)
    and vim.fn.filewritable(path) == 1
end

function M.save(buffer)
  local state = states[buffer]
  if
    not state
    or state.saving
    or not vim.api.nvim_buf_is_valid(buffer)
    or not eligible(buffer)
    or not vim.bo[buffer].modified
  then
    return
  end
  if not state.stamp or not vim.deep_equal(state.stamp, stamp(buffer)) then
    if not state.warned then
      vim.notify("Note changed on disk; autosave paused. Review with :checktime before saving.", vim.log.levels.WARN)
      state.warned = true
    end
    return
  end
  state.saving = true
  local ok, err = pcall(vim.api.nvim_buf_call, buffer, function()
    vim.cmd("silent update")
  end)
  state.saving = false
  if not ok then
    vim.notify("Note autosave failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.attach(buffer)
  if
    states[buffer]
    or vim.bo[buffer].filetype ~= "markdown"
    or not require("config.notes").contains(vim.api.nvim_buf_get_name(buffer))
  then
    return
  end
  states[buffer] = { stamp = stamp(buffer) }
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = group,
    buffer = buffer,
    callback = function()
      states[buffer].stamp, states[buffer].warned = stamp(buffer), nil
    end,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "FocusLost" }, {
    group = group,
    buffer = buffer,
    nested = true,
    callback = function()
      M.save(buffer)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buffer,
    once = true,
    callback = function()
      states[buffer] = nil
    end,
  })
end

return M
