-- Deliberately line-based: predictable edits, normal undo, no selection heuristics.
local M = {}
M.items = {
  { "heading", "Heading (level 2)" },
  { "bold", "Bold" },
  { "italic", "Italic" },
  { "strike", "Strikethrough" },
  { "code", "Inline code" },
  { "bullet", "Bullet" },
  { "numbered", "Numbered item" },
  { "task", "Task" },
  { "quote", "Quote" },
  { "callout", "Note callout" },
  { "block", "Code block" },
  { "link", "Markdown link" },
  { "wiki", "Wiki link" },
  { "table", "Insert table below" },
}
local wrappers = { bold = "**", italic = "*", strike = "~~", code = "`", wiki = "[[" }
local prefixes = { heading = "## ", bullet = "- ", numbered = "1. ", task = "- [ ] ", quote = "> " }

local function transform(kind, line, url)
  local indent, text = line:match("^(%s*)(.*)$")
  local replacement
  if wrappers[kind] then
    local mark = wrappers[kind]
    replacement = { indent .. mark .. text .. (kind == "wiki" and "]]" or mark) }
  elseif prefixes[kind] then
    if kind == "heading" then
      text = text:gsub("^#+%s+", "")
    end
    replacement = { indent .. prefixes[kind] .. text }
  elseif kind == "callout" then
    replacement = { indent .. "> [!NOTE]", indent .. "> " .. text }
  elseif kind == "block" then
    replacement = { indent .. "```", line, indent .. "```" }
  elseif kind == "link" and url and url ~= "" then
    if text:find("[%[%]]") or url:find("[%s()]") then
      vim.notify("Use plain link text and a URL without spaces or parentheses.", vim.log.levels.WARN)
      return
    end
    replacement = { indent .. "[" .. text .. "](" .. url .. ")" }
  end
  return replacement
end

function M.apply(kind, url)
  if not require("config.note_edit").writable() then
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  if kind == "table" then
    -- table-nvim replaces the current line, so give it a new blank line first.
    vim.api.nvim_buf_set_lines(0, row, row, false, { "" })
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
    require("table-nvim.edit").insert_table()
  else
    local replacement = transform(kind, vim.api.nvim_get_current_line(), url)
    if replacement then
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, replacement)
    end
  end
end

function M.menu()
  if not require("config.note_edit").writable() then
    return
  end
  local buffer = vim.api.nvim_get_current_buf()
  local tick = vim.api.nvim_buf_get_changedtick(buffer)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local function apply(kind, url)
    if vim.api.nvim_get_current_buf() ~= buffer or vim.api.nvim_buf_get_changedtick(buffer) ~= tick then
      vim.notify("Note changed while the menu was open; reopen Formatting.", vim.log.levels.WARN)
      return
    end
    vim.api.nvim_win_set_cursor(0, cursor)
    M.apply(kind, url)
  end
  Snacks.picker.select(M.items, {
    prompt = "Format current line",
    format_item = function(item)
      return item[2]
    end,
  }, function(item)
    if not item then
      return
    end
    if item[1] == "link" then
      vim.ui.input({ prompt = "Link URL: " }, function(url)
        apply("link", url)
      end)
    else
      apply(item[1])
    end
  end)
end

return M
