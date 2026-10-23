local root = vim.fn.stdpath("config")
vim.cmd("doautocmd User VeryLazy")
require("config.lazy_validation").assert_valid_spec()
local config = require("lazy.core.config")
local lock = vim.json.decode(table.concat(vim.fn.readfile(root .. "/lazy-lock.json"), "\n"))
local count = 0
for name, plugin in pairs(config.plugins) do
  assert(plugin._.installed, "review cannot install missing plugin: " .. name)
  assert(lock[name], "resolved plugin has no lockfile entry: " .. name)
  local result = vim.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }, { text = true }):wait()
  assert(
    result.code == 0 and vim.trim(result.stdout) == lock[name].commit,
    "installed revision differs from lock: " .. name
  )
  count = count + 1
end
for name in pairs(lock) do
  assert(config.plugins[name], "lockfile contains an undeclared plugin: " .. name)
end
assert(LazyVim.pick.picker.name == "snacks", "general navigation must use Snacks")
assert(vim.fn.maparg("<leader>ac", "n", false, true).desc == "CodeCompanion chat", "Claude shadows CodeCompanion chat")
assert(
  vim.fn.maparg("<leader>aa", "n", false, true).desc == "CodeCompanion actions",
  "Claude shadows CodeCompanion actions"
)
assert(vim.fn.maparg("<leader>ai", "n", false, true).desc == "Toggle Claude", "Claude toggle is missing")
assert(vim.fn.maparg("<leader>ay", "n", false, true).desc == "Accept diff", "Claude diff acceptance is missing")
assert(vim.fn.maparg("<leader>uC", "n", false, true).desc == "Colorschemes", "theme picker is missing")
assert(
  not config.plugins["copilot.lua"]._.loaded and not config.plugins["claudecode.nvim"]._.loaded,
  "QA must not activate AI clients"
)
print("PASS resolved plugin set and " .. count .. " installed revisions match the reviewed lockfile")
print("PASS Snacks navigation, persistent theme picker, and distinct AI shortcuts")

-- Parser/query compatibility is checked without calling install or update.
local languages = require("config.treesitter_languages")
local installed = {}
for _, language in ipairs(require("nvim-treesitter").get_installed("parsers")) do
  installed[language] = true
end
for _, language in ipairs(languages) do
  assert(installed[language], "required parser is missing: " .. language)
  local checked = {}
  for _, path in ipairs(vim.api.nvim_get_runtime_file("queries/" .. language .. "/*.scm", true)) do
    local kind = vim.fs.basename(path):gsub("%.scm$", "")
    if not checked[kind] then
      checked[kind] = true
      local ok, err = pcall(vim.treesitter.query.get, language, kind)
      assert(ok, language .. ":" .. kind .. ": " .. tostring(err))
    end
  end
end
print("PASS " .. #languages .. " installed parsers and shipped query compatibility (no updates)")

-- Use the actual Snacks implementation; no files or user buffers are involved.
local show = Snacks.dashboard
local shown = 0
Snacks.dashboard = function()
  shown = shown + 1
end
local close = assert(vim.fn.maparg("<leader>bh", "n", false, true).callback)
local buf = vim.api.nvim_get_current_buf()
close()
assert(not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted, "last buffer was not deleted")
assert(shown == 1, "successful last-buffer deletion must show the dashboard")
buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved QA buffer" })
local confirm = vim.fn.confirm
vim.fn.confirm = function()
  return 3
end
close()
vim.fn.confirm = confirm
assert(vim.api.nvim_get_current_buf() == buf and vim.bo[buf].modified, "cancel discarded unsaved edits")
assert(shown == 1, "cancelled deletion opened the dashboard")
Snacks.dashboard = show
vim.bo[buf].modified = false
print("PASS real Snacks deletion and cancelled unsaved-buffer protection")
