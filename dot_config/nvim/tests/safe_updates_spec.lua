local config_root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
package.path = table.concat({
  vim.fs.joinpath(config_root, "lua", "?.lua"),
  vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
  package.path,
}, ";")

local manager = require("config.safe_updates")
assert(manager.pending == nil, "requiring the update manager must have no scheduling side effects")

manager.setup()
manager.setup()

for _, command in ipairs({ "LazySafeUpdate", "LazySafeUpdateStatus", "LazySafeUpdateCancel" }) do
  assert(vim.fn.exists(":" .. command) == 2, command .. " was not registered")
end
assert(manager.pending == nil, "headless setup must never queue an update")

print("PASS safe update manager headless behavior")
