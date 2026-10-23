--- @since 26.8.15
--- @diagnostic disable: undefined-global, undefined-field

-- Yatline 0.5.0 predates Yazi's Url.spec API and File icon matcher.
-- Keep the upstream package managed by `ya pkg`; override only the affected
-- component getters until https://github.com/imsi32/yatline.yazi is updated.
local yatline = require("yatline")

if not Yatline or not Yatline.string or not Yatline.string.get or not Yatline.coloreds then
	error("yatline-compat requires Yatline 0.5.x")
end

local function middle_truncate(value, max_length, trim_length)
	if not max_length or not trim_length then
		return value
	end

	local length = utf8.len(value)
	if not length or length <= max_length or length <= trim_length * 2 then
		return value
	end

	local head_end = utf8.offset(value, trim_length + 1)
	local tail_start = utf8.offset(value, length - trim_length + 1)
	if not head_end or not tail_start then
		return value
	end

	return value:sub(1, head_end - 1) .. "..." .. value:sub(tail_start)
end

function Yatline.string.get:hovered_file_extension(show_icon)
	local hovered = cx.active.current.hovered
	if not hovered then
		return ""
	end

	local name = hovered.cha.is_dir and "dir" or (hovered.url.ext or "null")
	if not show_icon then
		return name
	end

	local icon = th.icon:match(hovered)
	return icon and (icon.text .. " " .. name) or name
end

function Yatline.string.get:tab_path(trimmed, max_length, trim_length)
	local cwd = cx.active.current.cwd
	local filter = cx.active.current.files.filter
	local finder = cx.active.finder
	local flags = {}

	if cwd.spec.is_search then
		flags[#flags + 1] = string.format("search: %s", cwd.spec.domain)
	end
	if filter then
		flags[#flags + 1] = string.format("filter: %s", filter)
	end
	if finder then
		flags[#flags + 1] = string.format("find: %s", finder)
	end

	local path = ya.readable_path(tostring(cwd))
	if trimmed then
		path = middle_truncate(path, max_length or 24, trim_length or 10)
	end

	return #flags == 0 and path or (path .. " (" .. table.concat(flags, ", ") .. ")")
end

function Yatline.string.get:search_query(key)
	local cwd = cx.active.current.cwd
	if not cwd.spec.is_search then
		return ""
	end

	return string.format("%s %s", key or "search:", cwd.spec.domain)
end

function Yatline.coloreds.get:count(filter, zero_check)
	filter = filter or false
	zero_check = zero_check or false

	local num_yanked = #cx.yanked
	local num_selected = #cx.active.selected
	local num_files = #cx.active.current.files
	local coloreds = {}

	if filter then
		local filtered = cx.active.current.files.filter or cx.active.current.cwd.spec.is_search
		local style = filtered and Yatline.config.filtereds or Yatline.config.files

		if not zero_check or num_files > 0 then
			coloreds[#coloreds + 1] = { string.format("%s %d", style.icon, num_files), style.fg }
		end
	end

	if not zero_check or num_selected > 0 then
		if #coloreds > 0 then
			coloreds[#coloreds + 1] = { " ", Yatline.config.selected.fg }
		end
		coloreds[#coloreds + 1] = {
			string.format("%s %d", Yatline.config.selected.icon, num_selected),
			Yatline.config.selected.fg,
		}
	end

	if not zero_check or num_yanked > 0 then
		local style = cx.yanked.is_cut and Yatline.config.cut or Yatline.config.copied
		if #coloreds > 0 then
			coloreds[#coloreds + 1] = { " ", style.fg }
		end
		coloreds[#coloreds + 1] = { string.format("%s %d", style.icon, num_yanked), style.fg }
	end

	return #coloreds > 0 and coloreds or nil
end

return {
	setup = function(_, config, pre_theme)
		return yatline:setup(config, pre_theme)
	end,
}
