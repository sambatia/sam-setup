local M = {}
-- Home dispatches the existing mappings so there is only one implementation of each workflow.
M.actions = {
  { key = "oi", label = "Quick idea" },
  { key = "on", label = "New note" },
  { key = "od", label = "Today" },
  { key = "of", label = "Find note" },
  { key = "os", label = "Search notes" },
  { key = "or", label = "Recent notes" },
  { key = "ob", label = "Backlinks", note = true },
  { key = "ol", label = "Links", note = true },
  { key = "o#", label = "Tags" },
  { key = "ot", label = "New note from template" },
  { key = "op", label = "Paste image", note = true },
  { key = "um", label = "Toggle Markdown rendering", note = true },
  { key = "cp", label = "Browser preview", note = true },
  { key = "cs", label = "Outline", note = true },
  { key = "o?", label = "Beginner help" },
  { key = "om", label = "Format current line", note = true },
  { key = "ox", label = "Toggle task", note = true },
  { key = "ov", label = "Toggle metadata", note = true },
  { key = "oz", label = "Focus note", note = true },
}

local function key_label(key)
  return "Space " .. table.concat(vim.split(key, ""), " ")
end

function M.home()
  local in_note = require("config.note_edit").in_vault()
  Snacks.picker.select(M.actions, {
    prompt = "Notes Home",
    format_item = function(item)
      local hint = item.note and not in_note and " (open a note first)" or ""
      return item.label .. "   " .. key_label(item.key) .. hint
    end,
  }, function(item)
    if not item then
      return
    end
    if item.note and not require("config.note_edit").in_vault() then
      vim.notify("Open a vault note first: Space o n or Space o f.", vim.log.levels.INFO)
      return
    end
    vim.api.nvim_feedkeys(" " .. item.key, "m", false)
  end)
end

local help_intro = {
  "WRITE",
  "i  Start typing      o  New line below + type",
  "Esc  Stop typing     u  Undo     Ctrl-r  Redo",
  "",
  "Personal vault notes auto-save on Esc, leaving the",
  "buffer, or losing focus. New file? Save once with :w.",
  "Code and Markdown outside the vault do not auto-save.",
  "",
  "NOTES",
  "Space o h  Notes Home (all actions)",
}

local help_markdown = {
  "",
  "MARKDOWN",
  "# Main heading       ## Heading",
  "- Bullet             1. Numbered item",
  "- [ ] Task           Enter continues a list",
  "Enter on an empty item ends the list.",
  "**bold**  *italic*  ~~strike~~  `inline code`",
  "[[note]] links; Enter follows a link in normal mode.",
  "",
  "HELPFUL",
  "Formatting menu edits the current line; u undoes it.",
  "Metadata is folded, intact: Space o v opens/closes it.",
  "Space c f  Format file (explicit; may reflow text)",
  ":NotesLint  Check Markdown style on request",
  ":w  Save now       :checktime  Check external changes",
  "j / k  Down / up    gg  Top    G  Bottom",
  "",
  "q / Esc  Close this help",
}

local function help_lines()
  local lines = vim.deepcopy(help_intro)
  for _, item in ipairs(M.actions) do
    lines[#lines + 1] = string.format("%-14s %s", key_label(item.key), item.label)
  end
  return vim.list_extend(lines, help_markdown)
end

function M.help()
  return Snacks.win({
    text = help_lines(),
    enter = true,
    width = 66,
    height = 0.85,
    border = "rounded",
    title = " Notes help ",
    ft = "text",
    bo = { modifiable = false, readonly = true, buftype = "nofile", bufhidden = "wipe" },
    wo = { wrap = true, conceallevel = 0 },
    keys = { q = "close", ["<Esc>"] = "close" },
  })
end

function M.focus()
  if not require("config.note_edit").in_vault() then
    return
  end
  local autocmd
  Snacks.zen({
    -- Window-local calm; do not change global diagnostics, signs or dimming in coding buffers.
    toggles = {},
    win = {
      width = 90,
      wo = { number = false, relativenumber = false, signcolumn = "no", statuscolumn = "", wrap = true },
    },
    on_open = function(win)
      autocmd = vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
          if vim.bo.buftype == "" and not require("config.note_edit").in_vault() then
            vim.schedule(function()
              if win:valid() then
                win:close()
              end
            end)
          end
        end,
      })
    end,
    on_close = function()
      if autocmd then
        vim.api.nvim_del_autocmd(autocmd)
      end
    end,
  })
end

return M
