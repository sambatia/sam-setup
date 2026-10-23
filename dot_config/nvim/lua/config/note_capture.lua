local M = {}

function M.append(text)
  if not text or vim.trim(text) == "" then
    return nil
  end
  local ok, result = pcall(function()
    local notes = require("config.notes")
    local folder = notes.root .. "/00-inbox"
    notes.ensure_dir(folder)
    local file = folder .. "/" .. os.date("%Y-%m-%d") .. "-ideas.md"
    local buffer = vim.fn.bufnr(file)
    -- Never save over unsaved edits in an open capture log.
    if buffer ~= -1 and vim.bo[buffer].modified then
      file = folder .. "/idea-" .. os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(vim.uv.hrtime()) .. ".md"
      buffer = -1
    end
    local entry = "\n## " .. os.date("%H:%M:%S") .. "\n\n" .. text:gsub("\r\n", "\n") .. "\n"
    local fd = assert(vim.uv.fs_open(file, "a", 384))
    -- O_APPEND and one write keep concurrent captures from replacing one another.
    local written, err = vim.uv.fs_write(fd, entry, -1)
    local synced, sync_err = vim.uv.fs_fsync(fd)
    local closed, close_err = vim.uv.fs_close(fd)
    assert(written == #entry, err or "Incomplete capture write")
    assert(synced, sync_err)
    assert(closed, close_err)
    if buffer ~= -1 and vim.api.nvim_buf_is_loaded(buffer) then
      vim.api.nvim_buf_call(buffer, function()
        vim.cmd.checktime()
      end)
    end
    return file
  end)
  if ok then
    return result
  end
  return nil, result
end

function M.prompt()
  vim.ui.input({ prompt = "Quick idea: " }, function(text)
    if not text or vim.trim(text) == "" then
      return
    end
    local file, err = M.append(text)
    if file then
      vim.notify("Idea saved: " .. vim.fn.fnamemodify(file, ":~"), vim.log.levels.INFO, { title = "Notes" })
    else
      -- Keep failed input recoverable without replacing the working buffer.
      local buffer = vim.api.nvim_create_buf(true, true)
      vim.bo[buffer].bufhidden = "hide"
      vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(text, "\n", { plain = true }))
      vim.notify("Capture failed: " .. tostring(err) .. ". Recover text with :buffer " .. buffer, vim.log.levels.ERROR)
    end
  end)
end

return M
