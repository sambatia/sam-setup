local M = {}

function M.interval_elapsed(now, last_success, interval)
  if type(now) ~= "number" or type(last_success) ~= "number" or type(interval) ~= "number" then
    return false
  end
  return interval >= 0 and now - last_success >= interval
end

function M.evaluate(context)
  if context.headless then
    return false, "headless"
  end
  if not context.has_ui then
    return false, "no-ui"
  end
  if context.dirty then
    return false, "dirty-config"
  end
  if not context.backup_exists then
    return false, "missing-backup"
  end
  if context.lock_exists then
    return false, "update-running"
  end
  if context.update_running then
    return false, "lazy-running"
  end
  if not context.lockfile_valid then
    return false, "invalid-lockfile"
  end
  if not context.config_valid then
    return false, "invalid-config"
  end
  if not context.manual and not M.interval_elapsed(context.now, context.last_success, context.interval) then
    return false, "not-due"
  end
  return true, "eligible"
end

return M
