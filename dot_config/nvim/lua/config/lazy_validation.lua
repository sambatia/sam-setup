local M = {}

local function current_spec()
  local ok, config = pcall(require, "lazy.core.config")
  return ok and config.spec or nil
end

function M.spec_errors(spec)
  spec = spec or current_spec()
  if type(spec) ~= "table" then
    return { "lazy.nvim specification is unavailable" }
  end

  local errors = {}
  for _, notification in ipairs(spec.notifs or {}) do
    local level = notification.level or vim.log.levels.ERROR
    if level >= vim.log.levels.ERROR then
      local message = tostring(notification.msg or "unknown specification error")
      if notification.file and notification.file ~= "" then
        message = ("%s: %s"):format(notification.file, message)
      end
      errors[#errors + 1] = message
    end
  end
  return errors
end

function M.spec_is_valid(spec)
  return #M.spec_errors(spec) == 0
end

function M.assert_valid_spec(spec)
  local errors = M.spec_errors(spec)
  assert(#errors == 0, "lazy.nvim specification errors:\n- " .. table.concat(errors, "\n- "))
end

function M.assert_no_task_errors()
  local failures = {}

  for name, plugin in pairs(require("lazy.core.config").plugins) do
    for _, task in ipairs(plugin._.tasks or {}) do
      if task:has_errors() then
        failures[#failures + 1] = name
        break
      end
    end
  end

  table.sort(failures)
  assert(#failures == 0, "lazy.nvim tasks failed for: " .. table.concat(failures, ", "))
end

function M.run_runtime_smoke(path)
  assert(type(path) == "string" and path ~= "", "runtime smoke path is required")
  local ok, error_message = xpcall(dofile, debug.traceback, path)
  if not ok then
    vim.api.nvim_err_writeln(tostring(error_message))
    vim.cmd("cquit 1")
  end
end

return M
