local M = {}

function M.in_vault(buffer)
  buffer = buffer or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buffer)
  return vim.bo[buffer].filetype == "markdown"
    and vim.bo[buffer].buftype == ""
    and path ~= ""
    and require("config.notes").contains(path)
end

function M.writable()
  if not M.in_vault() or vim.bo.readonly or not vim.bo.modifiable then
    vim.notify("Open a writable vault note first.", vim.log.levels.INFO)
    return false
  end
  return true
end

local function protected_syntax()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  vim.treesitter.get_parser(0, "markdown"):parse({ row, row + 1 })
  local node = vim.treesitter.get_node({ ignore_injections = true })
  while node do
    if
      vim.tbl_contains({ "fenced_code_block", "indented_code_block", "minus_metadata", "plus_metadata" }, node:type())
    then
      return true
    end
    node = node:parent()
  end
  return false
end

function M.enter()
  local fallback = function()
    return _G.MiniPairs and MiniPairs.cr() or "\r"
  end
  if not M.in_vault() or protected_syntax() then
    return fallback()
  end
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col)
  local indent, marker, body = before:match("^(%s*)([-+*]%s+)(.*)$")
  if not marker then
    local number, delimiter
    indent, number, delimiter, body = before:match("^(%s*)(%d+)([.)]%s+)(.*)$")
    if number then
      marker = tostring(tonumber(number) + 1) .. delimiter
    end
  end
  if not marker then
    return fallback()
  end
  local task = body:match("^%[[ xX]%]%s*")
  if task then
    body, marker = body:sub(#task + 1), marker .. "[ ] "
  end
  if not (body .. line:sub(col + 1)):find("%S") then
    return vim.api.nvim_replace_termcodes('<C-\\><C-o>"_d0', true, false, true)
  end
  return vim.api.nvim_replace_termcodes('<CR><C-\\><C-o>"_d0', true, false, true) .. indent .. marker
end

function M.metadata()
  if not M.in_vault() then
    return
  end
  if vim.fn.foldclosed(1) == 1 then
    vim.cmd("1foldopen")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  else
    vim.lsp.foldclose("imports")
  end
end

local function fold_metadata(buffer)
  -- The in-process Obsidian server has no didOpen notification. Wait for
  -- Neovim's first folding response instead of guessing a timer delay.
  vim.api.nvim_create_autocmd("LspRequest", {
    group = "notes_ux",
    buffer = buffer,
    callback = function(event)
      local request = event.data.request
      if request.method ~= "textDocument/foldingRange" or request.type ~= "complete" then
        return
      end
      vim.schedule(function()
        for _, win in ipairs(vim.fn.win_findbuf(buffer)) do
          if vim.w[win].notes_metadata_buffer ~= buffer then
            vim.w[win].notes_metadata_buffer = buffer
            vim.wo[win][0].foldtext = "v:lua.vim.lsp.foldtext()"
            vim.lsp.foldclose("imports", win)
          end
        end
      end)
    end,
  })
end

function M.attach(buffer)
  if not M.in_vault(buffer) or vim.b[buffer].notes_ux then
    return
  end
  vim.b[buffer].notes_ux = true
  require("config.note_autosave").attach(buffer)
  fold_metadata(buffer)
  vim.keymap.set(
    "i",
    "<CR>",
    M.enter,
    { buffer = buffer, expr = true, replace_keycodes = false, desc = "Continue note list" }
  )
  for key, action in pairs({
    ox = { "<cmd>Obsidian toggle_checkbox<cr>", "Toggle note task" },
    om = {
      function()
        require("config.note_format").menu()
      end,
      "Format note line",
    },
    ov = { M.metadata, "Toggle note metadata" },
    oz = {
      function()
        require("config.note_ui").focus()
      end,
      "Focus note",
    },
  }) do
    vim.keymap.set("n", "<leader>" .. key, action[1], { buffer = buffer, desc = action[2] })
  end
end

return M
