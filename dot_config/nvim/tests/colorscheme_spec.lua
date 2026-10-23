local h = dofile(vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "helpers.lua"))
package.path = vim.fs.joinpath(h.root, "lua", "?.lua") .. ";" .. package.path
local theme = require("config.colorscheme")
local state_path = vim.fn.stdpath("state") .. "/colorscheme.json"

theme.load("default")
assert(vim.g.colors_name == "default", "missing preference should use fallback")
vim.o.background = "light"
vim.cmd.colorscheme("peachpuff")
assert(theme.save("peachpuff"), "could not save selected theme")
vim.cmd.colorscheme("elflord")
vim.o.background = "dark"
theme.load("default")
assert(vim.g.colors_name == "peachpuff" and vim.o.background == "light", "name and background must restore")

local previous = vim.fn.readfile(state_path)
vim.cmd.colorscheme("desert")
assert(vim.deep_equal(vim.fn.readfile(state_path), previous), "temporary colorscheme must not overwrite preference")
assert(#vim.fn.glob(state_path .. ".*.tmp", false, true) == 0, "successful save left a temporary file")

for _, content in ipairs({ "broken json", '{"name":"default|quit"}', '{"name":false}', "[]" }) do
  vim.fn.writefile({ content }, state_path)
  theme.load("default")
  assert(vim.g.colors_name == "default", "invalid saved state should use fallback")
end
vim.o.background = "dark"
vim.fn.writefile({ '{"name":"theme-not-installed","background":"light"}' }, state_path)
theme.load("default")
assert(vim.g.colors_name == "default" and vim.o.background == "dark", "missing theme must restore fallback background")

vim.fn.delete(state_path)
vim.fn.mkdir(state_path)
assert(not theme.save("desert"), "failed preference write must be reported")
assert(vim.fn.isdirectory(state_path) == 1, "failed write damaged existing state path")
assert(#vim.fn.glob(state_path .. ".*.tmp", false, true) == 0, "failed save left a temporary file")
h.pass("theme preference restore, temporary changes, invalid state and write failures")
