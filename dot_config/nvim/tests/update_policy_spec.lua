local config_root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
package.path = table.concat({
  vim.fs.joinpath(config_root, "lua", "?.lua"),
  vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
  package.path,
}, ";")

local policy = require("config.update_policy")

assert(not policy.interval_elapsed(100000, 13601, 86400), "86,399 seconds must not be due")
assert(policy.interval_elapsed(100000, 13600, 86400), "86,400 seconds must be due")
assert(not policy.interval_elapsed(604799, 0, 604800), "six days plus 86,399 seconds must not be due")
assert(policy.interval_elapsed(604800, 0, 604800), "seven days must be due")

local eligible = {
  now = 604800,
  last_success = 0,
  interval = 604800,
  headless = false,
  has_ui = true,
  dirty = false,
  backup_exists = true,
  lock_exists = false,
  lockfile_valid = true,
  config_valid = true,
  update_running = false,
  manual = false,
}

local ok, reason = policy.evaluate(eligible)
assert(ok and reason == "eligible", "valid automatic update must be eligible")

local blocked = {
  headless = "headless",
  has_ui = "no-ui",
  dirty = "dirty-config",
  backup_exists = "missing-backup",
  lock_exists = "update-running",
  lockfile_valid = "invalid-lockfile",
  config_valid = "invalid-config",
  update_running = "lazy-running",
}

for field, expected_reason in pairs(blocked) do
  local context = vim.deepcopy(eligible)
  if field == "has_ui" or field == "backup_exists" or field == "lockfile_valid" or field == "config_valid" then
    context[field] = false
  else
    context[field] = true
  end
  local allowed, actual_reason = policy.evaluate(context)
  assert(not allowed and actual_reason == expected_reason, field .. " guard returned " .. tostring(actual_reason))
end

local not_due = vim.deepcopy(eligible)
not_due.now = 604799
local allowed, not_due_reason = policy.evaluate(not_due)
assert(not allowed and not_due_reason == "not-due", "automatic interval guard failed")

not_due.manual = true
local manual_allowed, manual_reason = policy.evaluate(not_due)
assert(manual_allowed and manual_reason == "eligible", "manual request must bypass only the interval")

print("PASS safe update policy boundaries")
