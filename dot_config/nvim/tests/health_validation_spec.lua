local config_root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
package.path = table.concat({
  vim.fs.joinpath(config_root, "lua", "?.lua"),
  vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
  package.path,
}, ";")

local validation = require("config.health_validation")
assert(vim.deep_equal(validation.collect_errors({ "all good", "- ⚠️ WARNING optional provider" }), {}))

local errors = validation.collect_errors({
  "============================================================================",
  "- ❌ ERROR required executable is missing",
  "- LSP log level : WARN",
})
assert(#errors == 1 and errors[1]:find("required executable", 1, true), "health errors were not detected")

print("PASS health report error detection")
