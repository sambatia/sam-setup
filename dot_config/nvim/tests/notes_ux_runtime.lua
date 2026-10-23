local notes = require("config.notes")
assert(vim.env.NVIM_NOTES_DIR and notes.root:find("lazyvim%-notes%-qa"), "Disposable vault required")
vim.cmd("doautocmd User VeryLazy")
local function wait(test, message)
  assert(vim.wait(10000, test, 20), message)
end
local function keys(text)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), "xt", false)
end
local function lines(expected)
  assert(
    vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected),
    vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  )
end
assert(vim.fn.maparg(" oh", "n") ~= "", "Notes Home mapping missing")
assert(vim.fn.maparg(" o?", "n") ~= "", "Beginner help mapping missing")
local coding_foldtext = vim.wo.foldtext
notes.prepare()
local path = notes.root .. "/test.md"
local original =
  { "---", "created: 2026-09-24", "tags: []", "type: note", "---", "", "# Hello", "text", "", "", "- [ ] Task" }
vim.fn.writefile(original, path)
vim.cmd.edit(path)
wait(function()
  return #vim.lsp.get_clients({ bufnr = 0, name = "obsidian-ls" }) == 1
end, "vault LSP")
wait(function()
  return vim.fn.foldclosed(1) == 1
end, "frontmatter did not fold")
assert(vim.fn.foldclosedend(1) == 5, "fold hid note body")
keys(" ov")
assert(vim.fn.foldclosed(1) == -1, "metadata cannot be opened")
lines(original)
assert(require("render-markdown").get())
keys(" um")
assert(not require("render-markdown").get())
keys(" um")
assert(require("render-markdown").get())
lines(original)
print("PASS frontmatter fold/open and renderer toggle preserve source")

local lint = require("lint")
local ns = lint.get_namespace("markdownlint-cli2")
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0 })
vim.wait(600)
assert(#vim.diagnostic.get(0, { namespace = ns }) == 0, "vault live style diagnostics")
vim.cmd.NotesLint()
wait(function()
  return #vim.diagnostic.get(0, { namespace = ns }) > 0
end, "explicit lint unavailable")
vim.diagnostic.reset(ns, 0)
print("PASS vault skips live markdownlint and supports explicit lint")

for _, case in ipairs({
  { "- First", "- First", "- Second" },
  { "- [ ] First", "- [ ] First", "- [ ] Second" },
  { "- [x] First", "- [x] First", "- [ ] Second" },
  { "1. First", "1. First", "2. Second" },
  { "  9) First", "  9) First", "  10) Second" },
}) do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { case[1] })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  keys("A<CR>Second<Esc>")
  lines({ case[2], case[3] })
end
for _, item in ipairs({ "- ", "- [ ] ", "2. " }) do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { item })
  keys("ggA<CR><Esc>")
  lines({ "" })
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "```", "- literal", "```" })
keys("ggjA<CR>text<Esc>")
lines({ "```", "- literal", "text", "```" })
print("PASS bullets, numbers, fresh tasks, empty-list exit and code-block exclusion")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- [ ] Task", "Paragraph" })
keys("gg ox")
lines({ "- [x] Task", "Paragraph" })
keys(" ox")
lines({ "- [ ] Task", "Paragraph" })
keys("j ox")
lines({ "- [ ] Task", "Paragraph" })
print("PASS two-state checkbox and safe paragraph behavior")

local ui = require("config.note_ui")
local source_buf = vim.api.nvim_get_current_buf()
ui.help()
local help_buf = vim.api.nvim_get_current_buf()
assert(help_buf ~= source_buf and not vim.bo.modifiable and vim.bo.buftype == "nofile")
keys("q")
assert(vim.api.nvim_get_current_buf() == source_buf and not vim.api.nvim_buf_is_valid(help_buf))
ui.help()
keys("<Esc>")
assert(vim.api.nvim_get_current_buf() == source_buf)
ui.home()
wait(function()
  return #Snacks.picker.get() == 1
end, "Notes Home picker missing")
local home = Snacks.picker.get()[1]
wait(function()
  return #home:items() == #ui.actions
end, "Home actions missing")
local help_item
for _, item in ipairs(home:items()) do
  assert(not item.text:find("open a note first", 1, true), "Home lost its originating note context")
  if item.item.key == "o?" then
    help_item = item
  end
end
home.opts.actions.confirm(home, assert(help_item))
vim.wait(100)
keys("")
assert(vim.bo.buftype == "nofile" and not vim.bo.modifiable, "Home selection did not open help")
keys("q")
assert(vim.api.nvim_get_current_buf() == source_buf)
print("PASS actual Notes Home picker displays note actions and opens help")

local old_select, feed = Snacks.picker.select, vim.api.nvim_feedkeys
local routed = {}
Snacks.picker.select = function(items, _, callback)
  for _, item in ipairs(items) do
    callback(item)
  end
end
vim.api.nvim_feedkeys = function(value)
  table.insert(routed, value)
end
ui.home()
vim.api.nvim_feedkeys, Snacks.picker.select = feed, old_select
assert(#routed == #ui.actions, "Home skipped an action")
for i, action in ipairs(ui.actions) do
  assert(routed[i] == " " .. action.key, "Home routed wrong workflow")
  assert(vim.fn.maparg(routed[i], "n") ~= "", "Home action has no mapping: " .. action.key)
end
print("PASS help closes cleanly and every Home action routes to an installed mapping")

local layout, statusline, tabline = vim.fn.winlayout(), vim.o.laststatus, vim.o.showtabline
ui.focus()
assert(Snacks.zen.win and Snacks.zen.win:valid())
keys("GoFocus edit<Esc>")
ui.focus()
vim.wait(100)
assert(not Snacks.zen.win and vim.deep_equal(layout, vim.fn.winlayout()), "zen layout recovery")
assert(vim.o.laststatus == statusline and vim.o.showtabline == tabline)
print("PASS focus edit and complete layout recovery")

-- Opening a second listed buffer normally changes LazyVim's tabline visibility.
-- Establish that coding baseline first, then verify focus adds no persistent change.
vim.cmd.enew()
vim.bo.filetype = "lua"
local code_buf = vim.api.nvim_get_current_buf()
vim.wait(100)
local code_statusline, code_tabline = vim.o.laststatus, vim.o.showtabline
vim.cmd.buffer(source_buf)
ui.focus()
vim.cmd.buffer(code_buf)
wait(function()
  return not Snacks.zen.win or not Snacks.zen.win:valid()
end, "note focus leaked into coding buffer")
assert(vim.o.laststatus == code_statusline and vim.o.showtabline == code_tabline)
vim.cmd.buffer(source_buf)
print("PASS switching to code automatically restores normal layout")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Preserve me" })
keys("gg")
require("config.note_format").apply("table")
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "Preserve me")
assert(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]:find("|", 1, true), "table not inserted")
print("PASS existing table insertion preserves current line")

-- Exercise the real menu callback for every operation, including the URL prompt.
local format = require("config.note_format")
local select_fn, input_fn = Snacks.picker.select, vim.ui.input
for _, choice in ipairs(format.items) do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Menu text", "keep" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  Snacks.picker.select = function(_, _, callback)
    callback(choice)
  end
  vim.ui.input = function(_, callback)
    callback("https://example.com")
  end
  format.menu()
  assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] ~= "Menu text" or choice[1] == "table", choice[1])
end
Snacks.picker.select, vim.ui.input = select_fn, input_fn
print("PASS all formatting menu choices and link prompt execute")

vim.cmd("Obsidian new Unsaved UX")
wait(function()
  return vim.api.nvim_buf_get_name(0):find("unsaved-ux", 1, true) ~= nil
end, "new note")
keys("GoWritten without manual save<Esc>")
assert(not vim.bo.modified, "new Obsidian note did not autosave")
assert(table.concat(vim.fn.readfile(vim.api.nvim_buf_get_name(0)), "\n"):find("Written without manual save", 1, true))
print("PASS newly created Obsidian note saves on leaving insert mode")

local outside = notes.root .. "-outside.md"
vim.fn.writefile(original, outside)
vim.cmd.edit(outside)
assert(vim.wo.foldtext == coding_foldtext, "vault fold text leaked into project Markdown")
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0 })
wait(function()
  return #vim.diagnostic.get(0, { namespace = ns }) > 0
end, "outside lint suppressed")
assert(vim.fn.maparg(" ox", "n") == "" and vim.fn.maparg(" om", "n") == "", "vault mappings leaked")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- First" })
keys("ggA<CR>Second<Esc>")
lines({ "- First", "Second" })
assert(vim.fn.readfile(outside)[1] == "---", "outside Markdown autosaved")
vim.bo.modified = false
print("PASS outside Markdown retains lint and Enter without vault autosave or mappings")
require("config.lazy_validation").assert_no_task_errors()
