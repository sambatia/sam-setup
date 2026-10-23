local M = {}

local function find_root()
  if vim.env.NVIM_NOTES_DIR and vim.env.NVIM_NOTES_DIR ~= "" then
    return vim.fs.normalize(vim.fn.expand(vim.env.NVIM_NOTES_DIR))
  end
  for _, candidate in ipairs({ "~/Obsidian", "~/Documents/Obsidian" }) do
    local marker = vim.fs.find(".obsidian", { path = vim.fn.expand(candidate), type = "directory", limit = 1 })[1]
    if marker then
      return vim.fs.dirname(marker)
    end
  end
  return vim.fn.expand("~/notes")
end

M.root = find_root()
M.daily = vim.uv.fs_stat(M.root .. "/Daily Notes") and "Daily Notes" or "daily"
M.assets = vim.uv.fs_stat(M.root .. "/+") and "+" or "assets"
local config_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))

function M.ensure_dir(path)
  local stat = vim.uv.fs_stat(path)
  if stat then
    assert(stat.type == "directory", "Not a directory: " .. path)
    return
  end
  local parent = vim.fs.dirname(path)
  assert(parent and parent ~= path, "Cannot create directory: " .. path)
  M.ensure_dir(parent)
  local created, err, code = vim.uv.fs_mkdir(path, 448)
  if not created and code == "EEXIST" then
    stat = vim.uv.fs_stat(path)
    created = stat and stat.type == "directory"
  end
  assert(created, err)
end

function M.contains(path)
  path = vim.fs.normalize(vim.fn.resolve(vim.fn.fnamemodify(path, ":p")))
  local root = vim.fn.resolve(M.root)
  return path == root or vim.startswith(path, root .. "/")
end

function M.prepare()
  for _, folder in ipairs({ "00-inbox", M.daily, "templates", M.assets }) do
    M.ensure_dir(M.root .. "/" .. folder)
  end
  for _, name in ipairs({ "idea", "note", "project", "meeting", "daily" }) do
    local target = M.root .. "/templates/" .. name .. ".md"
    local ok, err, code =
      vim.uv.fs_copyfile(config_dir .. "/templates/notes/" .. name .. ".md", target, { excl = true })
    assert(ok or code == "EEXIST", err)
  end
end

-- Relative Markdown paths also work in previews and editors outside Obsidian.
function M.image_link(path)
  local root = vim.fn.resolve(M.root)
  local parent = vim.fn.resolve(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
  local relative = vim.fs.relpath(root, parent)
  assert(relative, "Image paste requires a saved note in the vault")
  local depth = relative == "." and 0 or #vim.split(relative, "/", { trimempty = true })
  local asset = assert(vim.fs.relpath(root, vim.fn.resolve(tostring(path))))
  return "![](<" .. string.rep("../", depth) .. asset .. ">)"
end

return M
