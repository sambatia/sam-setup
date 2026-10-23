-- Plugin initialization for Yazi 26.8.15+.

require("git"):setup({
	order = 1500,
})

require("smart-enter"):setup({
	-- Operate on the hovered entry only, matching Yazi's safe enter semantics.
	open_multi = false,
})

require("augment-command"):setup({
	-- smart-enter.yazi owns enter/open behavior; keep this plugin focused on
	-- create and smart-paste so the two plugins never compete.
	smart_enter = false,
	smart_paste = false,
	confirm_on_quit = false,
	open_file_after_creation = true,
	enter_directory_after_creation = true,
	use_default_create_behaviour = true,
	must_have_hovered_item = false,
	skip_single_subdirectory_on_enter = false,
	skip_single_subdirectory_on_leave = false,
	wraparound_file_navigation = false,
})

local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local pref_by_location = require("pref-by-location")
pref_by_location:setup({
	no_notify = true,
	save_path = state_home .. "/yazi/pref-by-location.json",
	prefs = {
		{
			location = pref_by_location:is_literal_string(os.getenv("HOME") .. "/Downloads"),
			sort = { "btime", reverse = true, dir_first = true },
			linemode = "btime",
		},
	},
})

-- Render tabs through Yatline because its fixed one-row layout cannot display
-- Yazi's dynamically expanded native multi-tab header. The compatibility
-- adapter keeps Yatline on Yazi's current Url.spec and theme icon APIs.
require("yatline-compat"):setup({
	section_separator = { open = "", close = "" },
	part_separator = { open = "", close = "" },
	inverse_separator = { open = "", close = "" },
	style_a = {
		fg = "#1e1e2e",
		bg_mode = {
			normal = "#89b4fa",
			select = "#f9e2af",
			un_set = "#f38ba8",
		},
	},
	style_b = { bg = "#313244", fg = "#cdd6f4" },
	style_c = { bg = "#1e1e2e", fg = "#bac2de" },
	permissions_t_fg = "#89b4fa",
	permissions_r_fg = "#f9e2af",
	permissions_w_fg = "#f38ba8",
	permissions_x_fg = "#a6e3a1",
	permissions_s_fg = "#6c7086",
	selected = { icon = "󰻭", fg = "#f9e2af" },
	copied = { icon = "", fg = "#a6e3a1" },
	cut = { icon = "", fg = "#f38ba8" },
	files = { icon = "", fg = "#89b4fa" },
	filtereds = { icon = "", fg = "#cba6f7" },
	show_background = true,
	header_line = {
		left = {
			section_a = {
				{ type = "line", name = "tabs", params = { "left" } },
			},
			section_b = {},
			section_c = {},
		},
		right = {
			section_a = {},
			section_b = {},
			section_c = {},
		},
	},
	status_line = {
		left = {
			section_a = {
				{ type = "string", name = "tab_mode" },
			},
			section_b = {
				{ type = "string", name = "hovered_size" },
			},
			section_c = {
				{ type = "string", name = "hovered_path", params = { true, 42, 18 } },
				{ type = "coloreds", name = "count", params = { true, false } },
			},
		},
		right = {
			section_a = {
				{ type = "string", name = "cursor_position" },
			},
			section_b = {
				{ type = "string", name = "cursor_percentage" },
			},
			section_c = {
				{ type = "coloreds", name = "permissions" },
			},
		},
	},
})

require("full-border"):setup({
	type = ui.Border.ROUNDED,
})
