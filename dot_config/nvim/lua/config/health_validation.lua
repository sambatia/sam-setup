local M = {}

function M.collect_errors(lines)
  local errors = {}
  for _, line in ipairs(lines) do
    if line:match("%f[%a]ERROR%f[%A]") then
      errors[#errors + 1] = line
    end
  end
  return errors
end

function M.assert_no_errors(buffer)
  buffer = buffer or 0
  local name = vim.api.nvim_buf_get_name(buffer)
  assert(vim.startswith(name, "health://"), "current buffer is not a health report: " .. name)

  local errors = M.collect_errors(vim.api.nvim_buf_get_lines(buffer, 0, -1, false))
  assert(#errors == 0, "health report contains errors:\n" .. table.concat(errors, "\n"))
end

return M
