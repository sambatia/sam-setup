local M = {}

local source = debug.getinfo(1, "S").source:sub(2)
M.root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))

function M.read(path)
  local full_path = vim.fs.joinpath(M.root, path)
  local file, err = io.open(full_path, "r")
  assert(file, err)
  local content = file:read("*a")
  file:close()
  return content
end

function M.json(path)
  return vim.json.decode(M.read(path))
end

function M.specs()
  local specs = {}
  local paths = vim.fn.glob(vim.fs.joinpath(M.root, "lua", "plugins", "*.lua"), false, true)
  table.sort(paths)
  for _, path in ipairs(paths) do
    local chunk, err = loadfile(path)
    assert(chunk, err)
    local returned = chunk()
    assert(type(returned) == "table", path .. " must return a table")
    for _, spec in ipairs(returned) do
      if type(spec) == "table" then
        table.insert(specs, spec)
      end
    end
  end
  return specs
end

function M.find_plugin(specs, repo)
  for _, spec in ipairs(specs) do
    if spec[1] == repo then
      return spec
    end
  end
end

function M.find_key(spec, lhs)
  for _, key in ipairs(spec.keys or {}) do
    if key[1] == lhs then
      return key
    end
  end
end

function M.contains(list, expected)
  for _, value in ipairs(list or {}) do
    if value == expected then
      return true
    end
  end
  return false
end

function M.same_list(actual, expected, message)
  assert(vim.deep_equal(actual, expected), message .. "\nactual: " .. vim.inspect(actual))
end

function M.pass(name)
  print("PASS " .. name)
end

return M
