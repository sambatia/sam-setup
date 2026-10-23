local M = {}

local function path()
  return vim.fn.stdpath("state") .. "/colorscheme.json"
end

local function valid_name(name)
  return type(name) == "string" and name:match("^[%w_.%-]+$") ~= nil
end

local function read()
  local file = io.open(path(), "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  local ok, saved = pcall(vim.json.decode, content)
  if ok and type(saved) == "table" and valid_name(saved.name) then
    return saved
  end
end

function M.load(fallback)
  local saved = read()
  local background = vim.o.background
  if saved then
    if saved.background == "dark" or saved.background == "light" then
      vim.o.background = saved.background
    end
    if pcall(vim.cmd.colorscheme, saved.name) then
      return
    end
    vim.o.background = background
  end
  vim.cmd.colorscheme(fallback)
end

function M.save(name)
  local temporary = path() .. "." .. vim.fn.getpid() .. ".tmp"
  local ok, err = pcall(function()
    assert(valid_name(name), "invalid colorscheme name")
    vim.fn.mkdir(vim.fn.stdpath("state"), "p")
    local value = vim.json.encode({ name = name, background = vim.o.background })
    assert(vim.fn.writefile({ value }, temporary) == 0, "could not write theme preference")
    assert(vim.uv.fs_rename(temporary, path()))
  end)
  if not ok then
    vim.fn.delete(temporary)
    vim.notify("Theme applied but could not be saved: " .. tostring(err), vim.log.levels.WARN)
  end
  return ok
end

function M.attach_picker(_, map)
  map({ "i", "n" }, "<CR>", function(prompt_bufnr)
    local selection = require("telescope.actions.state").get_selected_entry()
    if not selection then
      return
    end
    local name = selection.value
    -- Keep Telescope's own apply/close behavior, including preview cancellation.
    require("telescope.actions").select_default(prompt_bufnr)
    M.save(name)
  end)
  return true
end

return M
