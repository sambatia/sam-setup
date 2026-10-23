local function project_root(markers, dir)
  local match = vim.fs.find(markers, {
    path = dir,
    type = "file",
    upward = true,
  })[1]
  return match and vim.fs.dirname(match) or nil
end

---@type overseer.TemplateFileProvider
return {
  generator = function(search)
    local tasks = {}

    local go_root = project_root({ "go.work", "go.mod" }, search.dir)
    if go_root and vim.fn.executable("go") == 1 then
      tasks[#tasks + 1] = {
        name = "go test ./...",
        builder = function()
          return {
            cmd = { "go", "test", "./..." },
            cwd = go_root,
          }
        end,
      }
    end

    local python_root = project_root({ "pyproject.toml", "pytest.ini", "tox.ini", "setup.cfg" }, search.dir)
    if python_root and vim.fn.executable("pytest") == 1 then
      tasks[#tasks + 1] = {
        name = "pytest",
        builder = function()
          return {
            cmd = { "pytest" },
            cwd = python_root,
          }
        end,
      }
    end

    return tasks
  end,
}
