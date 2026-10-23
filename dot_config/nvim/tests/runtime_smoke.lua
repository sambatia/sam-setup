local function pass(message)
  print("PASS " .. message)
end

local function load(plugin)
  require("lazy").load({ plugins = { plugin } })
  local spec = assert(require("lazy.core.config").plugins[plugin], "unknown plugin: " .. plugin)
  assert(spec._.loaded, plugin .. " did not load")
end

local function command(name)
  assert(vim.fn.exists(":" .. name) == 2, ":" .. name .. " is unavailable")
end

-- Verify a normal Markdown file uses the existing renderer without loading the
-- vault-specific Obsidian integration.
local markdown = vim.fn.tempname() .. ".md"
vim.fn.writefile({ "# Runtime smoke test", "", "| A | B |", "| - | - |", "| 1 | 2 |" }, markdown)
vim.cmd.edit(vim.fn.fnameescape(markdown))
vim.wait(1000, function()
  return vim.bo.filetype == "markdown"
end)
local lazy_config = require("lazy.core.config")
assert(lazy_config.plugins["render-markdown.nvim"]._.loaded, "Markdown renderer did not load")
assert(not lazy_config.plugins["obsidian.nvim"]._.loaded, "Obsidian loaded outside a vault")
vim.cmd.bwipeout({ bang = true })
vim.fn.delete(markdown)
pass("single Markdown renderer and vault isolation")

-- CsvView must render virtually without changing buffer text or file content.
local csv = vim.fn.tempname() .. ".csv"
local csv_lines = { "name,value", "alpha,1", "beta,200" }
vim.fn.writefile(csv_lines, csv)
vim.cmd.edit(vim.fn.fnameescape(csv))
vim.wait(1000, function()
  return vim.bo.filetype == "csv"
end)
command("CsvViewEnable")
vim.cmd.CsvViewEnable()
vim.wait(1000)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), csv_lines), "CsvView changed buffer text")
assert(vim.deep_equal(vim.fn.readfile(csv), csv_lines), "CsvView changed file content")
assert(not vim.bo.modified, "CsvView marked the buffer modified")
vim.cmd.CsvViewDisable()
vim.cmd.bwipeout({ bang = true })
vim.fn.delete(csv)
pass("CsvView virtual rendering preserves data")

local semicolon_csv = vim.fn.tempname() .. ".csv"
vim.fn.writefile({ "name;value", "alpha;1", "beta;200" }, semicolon_csv)
vim.cmd.edit(vim.fn.fnameescape(semicolon_csv))
vim.wait(1000, function()
  return vim.bo.filetype == "csv"
end)
vim.cmd.CsvViewEnable()
assert(
  vim.wait(1000, function()
    return vim.b.csvview_info ~= nil
  end),
  "CsvView delimiter detection timed out"
)
assert(vim.b.csvview_info.delimiter.text == ";", "CsvView did not detect a semicolon delimiter")
vim.cmd.CsvViewDisable()
vim.cmd.bwipeout({ bang = true })
vim.fn.delete(semicolon_csv)
pass("CsvView semicolon detection")

load("treesj")
vim.cmd.enew()
vim.bo.filetype = "lua"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = { alpha = 1, beta = 2 }" })
vim.api.nvim_win_set_cursor(0, { 1, 15 })
require("treesj").toggle()
assert(vim.api.nvim_buf_line_count(0) > 1, "TreeSJ did not split a Lua table")
require("treesj").toggle()
assert(vim.api.nvim_buf_line_count(0) == 1, "TreeSJ did not join the Lua table")
vim.cmd.bwipeout({ bang = true })
pass("TreeSJ split and join")

for _, plugin in ipairs({
  "aerial.nvim",
  "codecompanion.nvim",
  "dial.nvim",
  "diffview-plus.nvim",
  "nvim-colorizer.lua",
  "octo.nvim",
  "overseer.nvim",
  "smart-splits.nvim",
  "undotree",
  "yanky.nvim",
}) do
  load(plugin)
end

for _, name in ipairs({
  "AerialToggle",
  "CodeCompanion",
  "DiffviewOpen",
  "Octo",
  "OverseerRun",
  "UndotreeToggle",
}) do
  command(name)
end
pass("lazy-loaded editor, Git, task, and AI commands")

vim.cmd.UndotreeToggle()
assert(
  vim.iter(vim.api.nvim_list_bufs()):any(function(buffer)
    return vim.api.nvim_buf_get_name(buffer):find("undotree", 1, true) ~= nil
  end),
  "Undotree did not open"
)
vim.cmd.UndotreeToggle()
pass("Undotree toggle")

vim.cmd.enew()
vim.bo.filetype = "lua"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local function smoke()", "  return true", "end" })
vim.cmd.AerialToggle()
assert(vim.bo.filetype == "aerial", "Aerial did not open")
vim.cmd.AerialToggle()
vim.cmd.bwipeout({ bang = true })
pass("Aerial outline toggle")

local overseer = require("overseer")
local task = overseer.new_task({ cmd = { "true" }, name = "runtime smoke test" })
task:start()
assert(
  vim.wait(5000, function()
    return task:is_complete()
  end),
  "Overseer smoke task timed out"
)
assert(task.status == require("overseer.constants").STATUS.SUCCESS, "Overseer smoke task failed")
pass("Overseer harmless task execution")
