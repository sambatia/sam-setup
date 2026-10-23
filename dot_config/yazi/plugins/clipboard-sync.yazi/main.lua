--- @since 26.8.15
--- @diagnostic disable: undefined-global

-- Yazi now reserves `clipboard` for its built-in clipboard module. Load the
-- package-managed XYenon/clipboard plugin behind a distinct local name so the
-- upstream package can still be upgraded with `ya pkg upgrade`.
local path = tostring(rt.path.config_dir:join("plugins/clipboard.yazi/main.lua"))
local ok, clipboard = pcall(dofile, path)

if not ok then
	error("clipboard-sync failed to load XYenon/clipboard: " .. tostring(clipboard))
end
if type(clipboard) ~= "table" or type(clipboard.entry) ~= "function" then
	error("clipboard-sync requires a compatible XYenon/clipboard plugin")
end

return {
	entry = function(_, job)
		return clipboard:entry(job)
	end,
}
