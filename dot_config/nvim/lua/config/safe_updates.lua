local policy = require("config.update_policy")

local M = {
  pending = nil,
  setup_done = false,
}

local function paths()
  local state = vim.fs.joinpath(vim.fn.stdpath("state"), "safe-plugin-updates")
  return {
    state = state,
    lock = vim.fs.joinpath(state, "update.lock"),
    result = vim.fs.joinpath(state, "last-result.json"),
    notified = vim.fs.joinpath(state, "last-notified"),
    last_attempt = vim.fs.joinpath(state, "last-attempt"),
    script = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "safe-plugin-update.sh"),
    lockfile = vim.fs.joinpath(vim.fn.stdpath("config"), "lazy-lock.json"),
  }
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local value = file:read("*a")
  file:close()
  return value
end

local function atomic_write(path, value)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local temporary = ("%s.%d.tmp"):format(path, vim.fn.getpid())
  local ok = vim.fn.writefile({ value }, temporary) == 0
  if ok then
    ok = (vim.uv or vim.loop).fs_rename(temporary, path)
  end
  if not ok then
    vim.fn.delete(temporary)
  end
  return not not ok
end

local function read_number(path)
  local value = read_file(path)
  value = value and tonumber(vim.trim(value))
  return value
end

local function decode_json_file(path)
  local value = read_file(path)
  if not value then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, value)
  return ok and type(decoded) == "table" and decoded or nil
end

local function backup_exists()
  local candidates = vim.fn.glob(vim.fn.expand("~/.config/nvim.backup.*"), false, true)
  for _, candidate in ipairs(candidates) do
    if
      vim.fn.isdirectory(candidate) == 1
      and vim.fn.filereadable(vim.fs.joinpath(candidate, "lazy-lock.json")) == 1
    then
      return true
    end
  end
  return false
end

local function lazy_is_running()
  local process_ok, process = pcall(require, "lazy.manage.process")
  if process_ok and next(process.running) ~= nil then
    return true
  end
  local checker_ok, checker = pcall(require, "lazy.manage.checker")
  return checker_ok and checker.running == true
end

local function config_is_valid()
  local ok, valid = pcall(function()
    return require("config.lazy_validation").spec_is_valid()
  end)
  return ok and valid == true
end

local reason_messages = {
  headless = "headless Neovim sessions cannot schedule updates",
  ["no-ui"] = "no interactive UI is attached",
  ["dirty-config"] = "the Neovim configuration subtree has uncommitted changes",
  ["missing-backup"] = "no verified full Neovim configuration backup exists",
  ["update-running"] = "another safe plugin update is already running",
  ["lazy-running"] = "lazy.nvim is already installing, checking, or updating plugins",
  ["invalid-lockfile"] = "lazy-lock.json is missing or invalid",
  ["invalid-config"] = "the loaded LazyVim specification is invalid",
  ["not-due"] = "the seven-day automatic-update interval has not elapsed",
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Safe plugin updates" })
end

local function build_context(manual, callback)
  local update_paths = paths()
  vim.fn.mkdir(update_paths.state, "p")

  local now = os.time()
  local last_attempt = read_number(update_paths.last_attempt)
  if not manual and not last_attempt then
    -- Give a newly installed policy a full grace interval before its first
    -- automatic update. Manual updates remain immediately available.
    atomic_write(update_paths.last_attempt, tostring(now))
    last_attempt = now
  end

  local context = {
    now = now,
    last_success = last_attempt or 0,
    interval = 7 * 24 * 60 * 60,
    headless = #vim.api.nvim_list_uis() == 0,
    has_ui = #vim.api.nvim_list_uis() > 0,
    dirty = true,
    backup_exists = backup_exists(),
    lock_exists = (vim.uv or vim.loop).fs_stat(update_paths.lock) ~= nil,
    lockfile_valid = decode_json_file(update_paths.lockfile) ~= nil,
    config_valid = config_is_valid(),
    update_running = lazy_is_running(),
    manual = manual,
  }

  vim.system(
    { "git", "-C", vim.fn.stdpath("config"), "status", "--porcelain", "--", "." },
    { text = true },
    function(result)
      context.dirty = result.code ~= 0 or vim.trim(result.stdout or "") ~= ""
      vim.schedule(function()
        callback(context)
      end)
    end
  )
end

local function queue(manual)
  if M.pending then
    notify(("A %s safe update is already queued for exit."):format(M.pending), vim.log.levels.WARN)
    return
  end

  build_context(manual, function(context)
    local allowed, reason = policy.evaluate(context)
    if not allowed then
      if manual then
        notify("Safe update was not queued: " .. (reason_messages[reason] or reason), vim.log.levels.WARN)
      end
      return
    end

    M.pending = manual and "manual" or "automatic"
    notify(("A %s safe plugin update is queued and will start after Neovim exits normally."):format(M.pending))
  end)
end

local function load_result()
  return decode_json_file(paths().result)
end

function M.queue_manual()
  queue(true)
end

function M.cancel()
  if M.pending then
    local pending = M.pending
    M.pending = nil
    notify(("Canceled the queued %s safe plugin update."):format(pending))
  else
    notify("No safe plugin update is queued.")
  end
end

function M.status()
  if M.pending then
    notify(("A %s safe plugin update is queued for exit."):format(M.pending))
    return
  end

  local result = load_result()
  if not result then
    notify("No safe plugin update has run yet.")
    return
  end

  local message = ("%s: %s"):format(result.status or "unknown", result.message or "no details")
  if result.log then
    message = message .. "\nLog: " .. result.log
  end
  notify(message, result.status == "failed" and vim.log.levels.ERROR or vim.log.levels.INFO)
end

local function report_previous_result()
  local result = load_result()
  if not result or not result.id then
    return
  end
  local update_paths = paths()
  local notified = read_file(update_paths.notified)
  if notified and vim.trim(notified) == result.id then
    return
  end

  local message = result.message or ("Safe plugin update finished with status " .. tostring(result.status))
  if result.log then
    message = message .. "\nLog: " .. result.log
  end
  notify(message, result.status == "success" and vim.log.levels.INFO or vim.log.levels.ERROR)
  atomic_write(update_paths.notified, result.id)
end

local function launch_pending()
  if not M.pending then
    return
  end

  local update_paths = paths()
  if lazy_is_running() then
    notify("Safe updater was not launched because lazy.nvim is still busy.", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable(update_paths.script) ~= 1 then
    notify("Safe updater script is missing or not executable.", vim.log.levels.ERROR)
    return
  end

  local mode = M.pending
  M.pending = nil
  local ok, process = pcall(vim.system, { update_paths.script, "--" .. mode }, {
    detach = true,
    env = {
      NVIM_SAFE_UPDATE_PARENT_PID = tostring(vim.fn.getpid()),
    },
  })
  if ok then
    M.detached_process = process
  else
    notify("Failed to launch the safe updater: " .. tostring(process), vim.log.levels.ERROR)
  end
end

function M.setup()
  if M.setup_done then
    return
  end
  M.setup_done = true

  vim.api.nvim_create_user_command("LazySafeUpdate", M.queue_manual, {
    desc = "Queue a verified plugin update for after Neovim exits",
  })
  vim.api.nvim_create_user_command("LazySafeUpdateStatus", M.status, {
    desc = "Show the latest safe plugin update result",
  })
  vim.api.nvim_create_user_command("LazySafeUpdateCancel", M.cancel, {
    desc = "Cancel a queued safe plugin update",
  })

  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  local group = vim.api.nvim_create_augroup("safe_plugin_updates", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = launch_pending,
  })

  vim.schedule(report_previous_result)
  if vim.g.safe_plugin_updates_enabled ~= false then
    vim.defer_fn(function()
      queue(false)
    end, 1500)
  end
end

return M
