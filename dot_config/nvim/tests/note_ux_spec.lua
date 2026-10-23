local h = dofile(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "helpers.lua"))
package.path = vim.fs.joinpath(h.root, "lua", "?.lua") .. ";" .. package.path
local root = vim.fn.tempname()
vim.env.NVIM_NOTES_DIR = root .. "/vault"
vim.fn.mkdir(vim.env.NVIM_NOTES_DIR, "p")
local function edit(path, lines)
  vim.cmd.enew({ bang = true })
  if lines then
    vim.fn.writefile(lines, path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.bo.filetype = "markdown"
end
local ok, err = pcall(function()
  local autosave = require("config.note_autosave")
  local path = vim.env.NVIM_NOTES_DIR .. "/note.md"
  edit(path, { "original" })
  local buf = vim.api.nvim_get_current_buf()
  autosave.attach(buf)
  autosave.attach(buf)
  local writes = 0
  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = buf,
    callback = function()
      writes = writes + 1
    end,
  })
  for _, event in ipairs({ "InsertLeave", "FocusLost", "BufLeave" }) do
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { event })
    vim.api.nvim_exec_autocmds(event, { buffer = buf })
    assert(vim.fn.readfile(path)[1] == event, event .. " did not save")
    vim.api.nvim_exec_autocmds(event, { buffer = buf })
  end
  assert(writes == 3, "autosave duplicated writes or suppressed write hooks")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "readonly" })
  vim.bo.readonly = true
  autosave.save(buf)
  assert(vim.fn.readfile(path)[1] == "BufLeave")
  vim.bo.readonly = false
  vim.fn.writefile({ "external replacement" }, path)
  local notify = vim.notify
  local warnings = 0
  vim.notify = function()
    warnings = warnings + 1
  end
  autosave.save(buf)
  autosave.save(buf)
  vim.notify = notify
  assert(warnings == 1 and vim.fn.readfile(path)[1] == "external replacement", "external edit was lost")
  vim.bo.modified = false
  edit(vim.env.NVIM_NOTES_DIR .. "/new.md")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "not yet saved" })
  autosave.attach(vim.api.nvim_get_current_buf())
  autosave.save(vim.api.nvim_get_current_buf())
  assert(vim.fn.filereadable(vim.api.nvim_buf_get_name(0)) == 0, "autosave created a new file")
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unnamed" })
  autosave.save(vim.api.nvim_get_current_buf())
  edit(root .. "/outside.md", { "outside" })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "do not save" })
  autosave.attach(vim.api.nvim_get_current_buf())
  autosave.save(vim.api.nvim_get_current_buf())
  assert(vim.fn.readfile(root .. "/outside.md")[1] == "outside")
  edit(vim.env.NVIM_NOTES_DIR .. "/code.lua", { "local x = 1" })
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x = 2" })
  autosave.attach(vim.api.nvim_get_current_buf())
  autosave.save(vim.api.nvim_get_current_buf())
  assert(vim.fn.readfile(vim.env.NVIM_NOTES_DIR .. "/code.lua")[1] == "local x = 1")
  h.pass("autosave events, idempotence, hooks, external changes and unsafe buffer boundaries")

  edit(path, { "safe original" })
  autosave.attach(vim.api.nvim_get_current_buf())
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "pending first save" })
  vim.cmd.write()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "after manual save" })
  autosave.save(vim.api.nvim_get_current_buf())
  assert(vim.fn.readfile(path)[1] == "after manual save", "explicit write did not refresh autosave baseline")
  local fail = vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function()
      error("QA write failure")
    end,
  })
  local error_notice
  vim.notify = function(message)
    error_notice = message
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "failed write" })
  autosave.save(vim.api.nvim_get_current_buf())
  vim.notify = notify
  vim.api.nvim_del_autocmd(fail)
  assert(error_notice and error_notice:find("QA write failure", 1, true), "write failure hidden")
  assert(vim.bo.modified and vim.fn.readfile(path)[1] == "after manual save")
  autosave.save(vim.api.nvim_get_current_buf())
  assert(not vim.bo.modified, "write failure left autosave permanently locked")
  local linked = vim.env.NVIM_NOTES_DIR .. "/linked.md"
  assert(vim.uv.fs_symlink(root .. "/outside.md", linked))
  edit(linked)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "symlink escaped" })
  autosave.attach(vim.api.nvim_get_current_buf())
  autosave.save(vim.api.nvim_get_current_buf())
  assert(vim.fn.readfile(root .. "/outside.md")[1] == "outside", "symlink escaped vault boundary")
  h.pass("manual save recovery, visible write failures and symlink boundary")

  local format = require("config.note_format")
  local cases = {
    heading = { "## Hello" },
    bold = { "**Hello**" },
    italic = { "*Hello*" },
    strike = { "~~Hello~~" },
    code = { "`Hello`" },
    bullet = { "- Hello" },
    numbered = { "1. Hello" },
    task = { "- [ ] Hello" },
    quote = { "> Hello" },
    callout = { "> [!NOTE]", "> Hello" },
    block = { "```", "Hello", "```" },
    link = { "[Hello](https://example.com)" },
    wiki = { "[[Hello]]" },
  }
  edit(path, { "Hello", "keep" })
  for name, expected in pairs(cases) do
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Hello", "keep" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    format.apply(name, "https://example.com")
    expected = vim.list_extend(vim.deepcopy(expected), { "keep" })
    h.same_list(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected, "format " .. name)
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "## café 🧠", "keep" })
  format.apply("heading")
  h.same_list(
    vim.api.nvim_buf_get_lines(0, 0, -1, false),
    { "## café 🧠", "keep" },
    "heading replaces existing marker"
  )
  h.pass("each line formatting operation preserves neighboring text and Unicode")
end)
vim.cmd.enew({ bang = true })
vim.fn.delete(root, "rf")
assert(ok, err)
