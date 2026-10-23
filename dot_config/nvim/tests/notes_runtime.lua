-- Run only with NVIM_NOTES_DIR pointing to a disposable directory.
local notes = require("config.notes")
assert(vim.env.NVIM_NOTES_DIR and notes.root:find("lazyvim%-notes%-qa"), "A disposable QA vault is required")
local function pass(message)
  print("PASS " .. message)
end
local function wait(test, message)
  assert(vim.wait(10000, test, 20), message)
end
vim.cmd("doautocmd User VeryLazy")
local plugins = require("lazy.core.config").plugins
require("config.lazy_validation").assert_valid_spec()
assert(not plugins["obsidian.nvim"]._.loaded, "Obsidian loaded before a note was opened")
assert(vim.fn.maparg(" n", "n", false, true).desc == "Notification History", "notification mapping changed")
assert(vim.fn.maparg(" oi", "n", false, true).desc == "Quick idea (save to inbox)")
local buf = vim.api.nvim_get_current_buf()
assert(require("config.note_capture").append("Runtime capture café 🧠\nSecond line"))
assert(vim.api.nvim_get_current_buf() == buf and not plugins["obsidian.nvim"]._.loaded)
pass("quick capture from a coding buffer without loading Obsidian")

vim.cmd("Obsidian new QA Target")
wait(function()
  return vim.api.nvim_buf_get_name(0):find("qa-target", 1, true) ~= nil
end, "new note did not open")
assert(not Obsidian._config_error, Obsidian._config_error)
local target = vim.api.nvim_buf_get_name(0)
assert(target:find("00-inbox", 1, true), "new note escaped inbox")
local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(content:find("type: note", 1, true) and not content:find("{{", 1, true), "default template was not expanded")
vim.cmd.write()
wait(function()
  return #vim.lsp.get_clients({ bufnr = 0, name = "obsidian-ls" }) == 1
end, "Obsidian LSP did not attach")
assert(#vim.lsp.get_clients({ bufnr = 0, name = "marksman" }) == 0, "duplicate vault LSP")
assert(vim.b.autoformat == false and Obsidian.opts.ui.enable == false)
pass("new note, template substitution, vault-only LSP and single renderer")

vim.cmd("Obsidian new_from_template QA Project project")
wait(function()
  return vim.api.nvim_buf_get_name(0):find("qa-project", 1, true) ~= nil
end, "project template note did not open")
assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("## Outcome", 1, true))
vim.cmd.write()
vim.cmd("Obsidian today")
wait(function()
  return vim.api.nvim_buf_get_name(0):find(os.date("%Y-%m-%d"), 1, true) ~= nil
end, "daily note did not open")
assert(vim.api.nvim_buf_get_name(0):find("/" .. notes.daily .. "/", 1, true))
assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("## Focus", 1, true))
vim.cmd.write()
pass("project and daily note templates")

local source = notes.root .. "/00-inbox/QA Source.md"
local lines = {
  "---",
  "tags: [qa-notes]",
  "type: note",
  "---",
  "",
  "# QA Source",
  "",
  "## Heading two",
  "",
  "### Heading three",
  "",
  "**bold** and *italic* and `inline code`.",
  "",
  "```lua",
  "print('example')",
  "```",
  "",
  "- Bullet",
  "",
  "1. Numbered item",
  "",
  "- [ ] Unchecked",
  "- [x] Checked",
  "",
  "> Blockquote",
  "",
  "> [!NOTE]",
  "> Callout",
  "",
  "| Name | Value |",
  "| --- | --- |",
  "| Alpha | One |",
  "",
  "[[qa-target]]",
  "",
  "[Example](https://example.com)",
  "",
  "#qa-notes",
  "",
}
vim.fn.writefile(lines, source)
vim.cmd.edit(vim.fn.fnameescape(source))
wait(function()
  return #vim.lsp.get_clients({ bufnr = 0, name = "obsidian-ls" }) == 1
end, "source LSP missing")
for _, lang in ipairs({ "markdown", "markdown_inline" }) do
  assert(pcall(vim.treesitter.language.add, lang), lang .. " parser missing")
end
local parser = vim.treesitter.get_parser(0, "markdown")
assert(parser:parse()[1]:root():type() == "document")
assert(plugins["render-markdown.nvim"]._.loaded and require("render-markdown").get())
assert(plugins["table-nvim"]._.loaded)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), lines), "rendering changed note text")
vim.api.nvim_win_set_cursor(0, { 34, 3 })
vim.cmd("Obsidian follow_link")
wait(function()
  return vim.api.nvim_buf_get_name(0) == target
end, "wiki link did not resolve")
local matches
require("obsidian.search").find_backlinks_async(require("obsidian.api").current_note(0), function(result)
  matches = result
end)
wait(function()
  return matches ~= nil
end, "backlinks timed out")
assert(#matches >= 1, "backlink was not found")
pass("Markdown parser/rendering, wiki link navigation and backlinks")

vim.cmd.edit(vim.fn.fnameescape(source))
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "[[qa-" })
vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 5 })
local client = assert(vim.lsp.get_clients({ bufnr = 0, name = "obsidian-ls" })[1])
local params = vim.lsp.util.make_position_params(0, "utf-8")
local completion = assert(client:request_sync("textDocument/completion", params, 10000, 0))
assert(not completion.err, vim.inspect(completion.err))
local items = completion.result.items or completion.result
assert(
  vim.iter(items):any(function(item)
    return item.label:lower():find("qa", 1, true) ~= nil
  end),
  "wiki completion missing"
)
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.modified = false
pass("wiki-link completion through the active Obsidian language server")

local function picker(command, match)
  vim.cmd(command)
  wait(function()
    return #Snacks.picker.get() > 0
  end, command .. " picker missing")
  local p = Snacks.picker.get()[1]
  wait(function()
    return vim.iter(p:items()):any(function(item)
      return vim.inspect(item):find(match, 1, true) ~= nil
    end)
  end, command .. " missing expected result")
  p:close()
  vim.wait(50)
end
picker("Obsidian quick_switch", "QA Source")
picker("Obsidian search Callout", "QA Source")
picker("Obsidian tags qa-notes", "QA Source")
vim.cmd.edit(vim.fn.fnameescape(source))
picker("Obsidian links", "qa-target")
vim.cmd.AerialToggle()
assert(vim.bo.filetype == "aerial", "outline did not open")
vim.cmd.AerialToggle()
pass("Snacks find, full-text search, tags, links and Aerial outline")

local ordinary = notes.root .. "-outside.md"
vim.fn.writefile({ "#    Ordinary Markdown", "", "Text." }, ordinary)
vim.cmd.edit(vim.fn.fnameescape(ordinary))
wait(function()
  return #vim.lsp.get_clients({ bufnr = 0, name = "marksman" }) == 1
end, "Marksman did not attach outside vault")
assert(#vim.lsp.get_clients({ bufnr = 0, name = "obsidian-ls" }) == 0, "Obsidian attached outside vault")
local names = vim.tbl_map(function(f)
  return f.name
end, require("conform").list_formatters(0))
assert(vim.tbl_contains(names, "prettier"), "Markdown formatter unavailable")
local format_done, format_error
require("conform").format({ async = false }, function(err)
  format_done, format_error = true, err
end)
assert(format_done and not format_error, "Conform failed: " .. tostring(format_error))
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "# Ordinary Markdown", "Prettier did not format heading")
vim.cmd.bwipeout({ bang = true })
vim.fn.delete(ordinary)
pass("Marksman and Conform outside vault without duplicate LSP clients")
require("config.lazy_validation").assert_no_task_errors()
