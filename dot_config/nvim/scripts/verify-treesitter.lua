local config_dir = vim.env.NVIM_CONFIG_DIR
assert(config_dir and config_dir ~= "", "NVIM_CONFIG_DIR is required")

local plugin_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "nvim-treesitter")
assert(vim.uv.fs_stat(plugin_dir), "nvim-treesitter is not installed at " .. plugin_dir)
vim.opt.runtimepath:prepend(plugin_dir)

local languages_file = vim.fs.joinpath(config_dir, "lua", "config", "treesitter_languages.lua")
local load_languages, load_error = loadfile(languages_file)
assert(load_languages, load_error)
local required = load_languages()
assert(type(required) == "table" and #required > 0, "Treesitter language list is empty")

local treesitter = require("nvim-treesitter")

local function missing_languages()
  local installed = {}
  for _, language in ipairs(treesitter.get_installed("parsers")) do
    installed[language] = true
  end

  local missing = {}
  for _, language in ipairs(required) do
    if not installed[language] then
      missing[#missing + 1] = language
    end
  end
  return missing
end

local missing = missing_languages()
if #missing > 0 then
  assert(vim.fn.executable("tree-sitter") == 1, "tree-sitter CLI is required to install parsers")
  treesitter.install(missing, { max_jobs = 4, summary = true }):wait(300000)
end

-- Parser revisions and query files move together on nvim-treesitter's main
-- branch. Updating the required set prevents an older parser from accepting
-- installation checks while failing at runtime on a newer query node.
treesitter.update(required, { max_jobs = 4, summary = true }):wait(300000)

missing = missing_languages()
assert(#missing == 0, "required Treesitter parsers are missing: " .. table.concat(missing, ", "))

local query_errors = {}
local checked_queries = {}
for _, language in ipairs(required) do
  local pattern = ("queries/%s/*.scm"):format(language)
  for _, path in ipairs(vim.api.nvim_get_runtime_file(pattern, true)) do
    local query_type = vim.fs.basename(path):gsub("%.scm$", "")
    local key = language .. ":" .. query_type
    if not checked_queries[key] then
      checked_queries[key] = true
      local ok, error_message = pcall(vim.treesitter.query.get, language, query_type)
      if not ok then
        query_errors[#query_errors + 1] = ("%s (%s): %s"):format(key, path, error_message)
      end
    end
  end
end

table.sort(query_errors)
assert(#query_errors == 0, "Treesitter query compatibility failures:\n" .. table.concat(query_errors, "\n"))
print(("PASS %d required Treesitter parsers and queries verified"):format(#required))
