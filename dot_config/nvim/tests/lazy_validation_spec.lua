local config_root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
package.path = table.concat({
  vim.fs.joinpath(config_root, "lua", "?.lua"),
  vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
  package.path,
}, ";")

local validation = require("config.lazy_validation")

local warning_only = {
  notifs = {
    { msg = "optional plugin warning", level = vim.log.levels.WARN, file = "plugins/example.lua" },
  },
}
assert(validation.spec_is_valid(warning_only), "warnings must not invalidate a Lazy specification")
assert(#validation.spec_errors(warning_only) == 0, "warnings must not be returned as spec errors")

local invalid = {
  notifs = {
    { msg = "optional plugin warning", level = vim.log.levels.WARN },
    { msg = "invalid plugin spec", level = vim.log.levels.ERROR, file = "plugins/broken.lua" },
  },
}
assert(not validation.spec_is_valid(invalid), "error diagnostics must invalidate a Lazy specification")
local errors = validation.spec_errors(invalid)
assert(#errors == 1, "exactly one Lazy specification error was expected")
assert(errors[1]:find("invalid plugin spec", 1, true), "the diagnostic message is missing")
assert(errors[1]:find("plugins/broken.lua", 1, true), "the diagnostic source file is missing")

local ok, err = pcall(validation.assert_valid_spec, invalid)
assert(not ok, "assert_valid_spec must fail for an invalid Lazy specification")
assert(tostring(err):find("invalid plugin spec", 1, true), "the assertion must include diagnostic context")

print("PASS current lazy.nvim specification diagnostics")
