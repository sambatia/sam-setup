-- Run through colorscheme-runtime.sh with the real configured Telescope picker.
local function active(name)
  if name == "kanagawa-wave" then
    return vim.g.colors_name == "kanagawa" and require("kanagawa")._CURRENT_THEME == "wave"
  end
  return vim.g.colors_name == name
end

local expected = vim.env.NVIM_THEME_EXPECTED
assert(active(expected), "startup did not restore " .. expected .. ": " .. tostring(vim.g.colors_name))
local target = vim.env.NVIM_THEME_SELECT
if not target or target == "" then
  print("PASS fresh startup restored " .. expected)
  return
end

vim.cmd("doautocmd User VeryLazy")
vim.o.lines, vim.o.columns = 55, 160
local function keys(text)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), "xt", false)
end
keys(" uC")
local picker
assert(
  vim.wait(5000, function()
    picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
    return picker and picker.manager and picker.manager:num_results() > 0
  end, 20),
  "Space u C did not open the picker; mapping="
    .. vim.inspect(vim.fn.maparg("<leader>uC", "n", false, true))
    .. "; filetype="
    .. vim.bo.filetype
    .. "; messages="
    .. vim.api.nvim_exec2("messages", { output = true }).output
)
local index, found = 1, false
for entry in picker.manager:iter() do
  if entry.value == target then
    picker:set_selection(picker:get_row(index))
    found = true
    break
  end
  index = index + 1
end
assert(found and vim.wait(1000, function()
  return active(target)
end, 10), "preview failed for " .. target)

local state_path = vim.fn.stdpath("state") .. "/colorscheme.json"
local function saved()
  if vim.fn.filereadable(state_path) == 0 then
    return nil
  end
  return vim.json.decode(table.concat(vim.fn.readfile(state_path), "\n")).name
end
assert(saved() == (vim.env.NVIM_THEME_SAVED ~= "" and vim.env.NVIM_THEME_SAVED or nil), "preview changed saved theme")
if vim.env.NVIM_THEME_CANCEL == "1" then
  -- Headless feedkeys finishes in normal mode; invoke the actual insert-mode mapping.
  local cancel = vim.fn.maparg("<C-c>", "i", false, true)
  assert(type(cancel.callback) == "function", "Telescope Ctrl-c mapping is missing")
  cancel.callback()
  assert(active(expected), "cancel did not restore previous theme")
  assert(saved() == vim.env.NVIM_THEME_SAVED, "cancel changed saved theme")
  print("PASS preview/cancel preserved " .. expected)
else
  if vim.env.NVIM_THEME_MODE == "i" then
    local select = vim.fn.maparg("<CR>", "i", false, true)
    assert(type(select.callback) == "function", "insert-mode Enter mapping is missing")
    select.callback()
  else
    keys("<CR>")
  end
  assert(active(target), "Enter did not apply selected theme")
  assert(saved() == target, "Enter did not persist " .. target)
  print("PASS Enter saved " .. target)
end
assert(not vim.api.nvim_buf_is_valid(picker.prompt_bufnr), "picker did not close")
