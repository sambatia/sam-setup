local h = dofile(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "helpers.lua"))
package.path = vim.fs.joinpath(h.root, "lua", "?.lua") .. ";" .. package.path
local root = vim.fn.tempname()
vim.env.NVIM_NOTES_DIR = root
local capture = require("config.note_capture")
local notes = require("config.notes")
local text = "Idea: café 🧠 — 'quotes', $HOME, `code` and \\ paths\nSecond line."
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved coding buffer" })
local buffer, window, cwd = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win(), vim.fn.getcwd()
local cursor = vim.api.nvim_win_get_cursor(window)
local ok, err = pcall(function()
  assert(capture.append(nil) == nil and capture.append(" \n ") == nil, "empty/cancelled captures must not write")
  assert(vim.uv.fs_stat(root) == nil, "cancelled capture created directories")
  local file = assert(capture.append(text))
  assert(file == root .. "/00-inbox/" .. os.date("%Y-%m-%d") .. "-ideas.md", "wrong capture location")
  local first = table.concat(vim.fn.readfile(file), "\n")
  assert(first:find("## " .. os.date("%H:%M"), 1, true), "capture lacks timestamp")
  assert(first:find(text, 1, true), "capture corrupted Unicode, punctuation or newlines")
  assert(capture.append("Second idea") == file)
  assert(table.concat(vim.fn.readfile(file), "\n"):find(first, 1, true) == 1, "append overwrote an earlier capture")
  assert(vim.api.nvim_get_current_buf() == buffer and vim.api.nvim_get_current_win() == window)
  assert(vim.fn.getcwd() == cwd and vim.deep_equal(vim.api.nvim_win_get_cursor(window), cursor))
  assert(vim.bo[buffer].modified and vim.api.nvim_buf_get_lines(buffer, 0, -1, false)[1] == "unsaved coding buffer")
  h.pass("durable repeated captures preserve text and editing context")

  local target = vim.fn.bufadd(file)
  vim.fn.bufload(target)
  vim.api.nvim_buf_set_lines(target, 0, -1, false, { "unsaved inbox edit" })
  local fallback = assert(capture.append("Capture while inbox is edited"))
  assert(fallback ~= file and vim.uv.fs_stat(fallback), "dirty capture buffer must receive a separate durable capture")
  assert(vim.bo[target].modified and vim.api.nvim_buf_get_lines(target, 0, -1, false)[1] == "unsaved inbox edit")
  vim.api.nvim_buf_delete(target, { force = true })
  h.pass("capture never overwrites an unsaved inbox buffer")

  notes.prepare()
  local template = root .. "/templates/note.md"
  assert(vim.uv.fs_stat(template), "templates were not seeded")
  vim.fn.writefile({ "user customization" }, template)
  notes.prepare()
  assert(vim.fn.readfile(template)[1] == "user customization", "repeat setup overwrote customized template")
  assert(notes.contains(root .. "/00-inbox/a.md") and not notes.contains(root .. "-other/a.md"))
  h.pass("idempotent setup preserves templates and vault boundary")

  -- Recursive mkdir can fail at a raced parent before creating the final folder.
  local original_root, original_mkdir = notes.root, vim.fn.mkdir
  notes.root = root .. "/mkdir-race/nested"
  vim.fn.mkdir = function(path, ...)
    original_mkdir(vim.fs.dirname(path), ...)
    error("E739: Cannot create directory: file already exists")
  end
  local raced_file, raced_error = capture.append("directory race capture")
  local prepared, prepare_error = pcall(notes.prepare)
  vim.fn.mkdir = original_mkdir
  notes.root = original_root
  assert(raced_file, raced_error)
  assert(prepared, prepare_error)
  assert(table.concat(vim.fn.readfile(raced_file), "\n"):find("directory race capture", 1, true))
  h.pass("directory creation handles a raced ancestor before the final folder exists")

  local original_fs_mkdir = vim.uv.fs_mkdir
  vim.uv.fs_mkdir = function(path, mode)
    local created, mkdir_err, code = original_fs_mkdir(path, mode)
    if created then
      return nil, "EEXIST: another process created the directory", "EEXIST"
    end
    return created, mkdir_err, code
  end
  local created, mkdir_err = pcall(notes.ensure_dir, root .. "/competing-process/nested")
  vim.uv.fs_mkdir = original_fs_mkdir
  assert(created, mkdir_err)
  assert(vim.fn.isdirectory(root .. "/competing-process/nested") == 1)
  h.pass("each directory component accepts a concurrent creator only after verifying its type")

  vim.api.nvim_buf_set_name(buffer, root .. "/00-inbox/nested/note.md")
  assert(notes.image_link(root .. "/assets/example image.png") == "![](<../../assets/example image.png>)")
  vim.api.nvim_buf_set_name(buffer, root .. "/note.md")
  assert(notes.image_link(root .. "/assets/example.png") == "![](<assets/example.png>)")
  h.pass("image links are relative to the saved note, including nested folders")

  -- Disk failure must return an error; the input callback retains recoverable text.
  vim.fn.delete(root .. "/00-inbox", "rf")
  vim.fn.writefile({ "blocking file" }, root .. "/00-inbox")
  local failed, message = capture.append("must not disappear")
  assert(failed == nil and message, "write failure was reported as success")
  local original_input, original_notify = vim.ui.input, vim.notify
  vim.ui.input = function(_, callback)
    callback("recover this idea")
  end
  vim.notify = function() end
  capture.prompt()
  vim.ui.input, vim.notify = original_input, original_notify
  local found = false
  for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
    if candidate ~= buffer and vim.api.nvim_buf_get_lines(candidate, 0, -1, false)[1] == "recover this idea" then
      found = true
    end
  end
  assert(found and vim.api.nvim_get_current_buf() == buffer, "failed capture input was lost or replaced working buffer")
  h.pass("failed capture keeps recoverable input without disturbing the editor")

  local race = root .. "-concurrent"
  local children = {}
  local code = string.format(
    "package.path=%q..';'..package.path; local f,e=require('config.note_capture').append(vim.env.CAPTURE_TEST_VALUE); if not f then io.stderr:write(tostring(e)); vim.cmd('cquit 1') end",
    vim.fs.joinpath(h.root, "lua", "?.lua")
  )
  for i = 1, 8 do
    children[i] = vim.system({ vim.v.progpath, "--clean", "--headless", "+lua " .. code, "+qa" }, {
      env = { NVIM_NOTES_DIR = race, CAPTURE_TEST_VALUE = "parallel-capture-" .. i },
      text = true,
    })
  end
  local errors = {}
  for _, child in ipairs(children) do
    local result = child:wait(10000)
    if result.code ~= 0 then
      errors[#errors + 1] = result.stderr
    end
  end
  local file = race .. "/00-inbox/" .. os.date("%Y-%m-%d") .. "-ideas.md"
  local data = vim.fn.filereadable(file) == 1 and table.concat(vim.fn.readfile(file), "\n") or ""
  vim.fn.delete(race, "rf")
  assert(#errors == 0, table.concat(errors, "\n"))
  for i = 1, 8 do
    local _, count = data:gsub("parallel%-capture%-" .. i, "")
    assert(count == 1, "concurrent capture lost or duplicated entry " .. i)
  end
  h.pass("concurrent first captures create directories and append exactly once")
end)
vim.fn.delete(root, "rf")
assert(ok, err)
