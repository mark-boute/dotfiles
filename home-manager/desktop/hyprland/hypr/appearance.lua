-- General appearance: layout, gaps, borders, decoration, animations, cursor,
-- misc. Ported from wayland.windowManager.hyprland.settings in default.nix.

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = {top = 0, left = 5, bottom = 5, right = 5},
        -- gaps_out = 5,
        gaps_workspaces = 50;
		border_size = 2,

        resize_on_border = true,

		["col.active_border"] = { colors = { "rgba(125,196,228,1)", "rgba(244,219,214,1)" }, angle = 45 },
		["col.inactive_border"] = { colors = { "rgba(125,196,228,0.5)", "rgba(244,219,214,0.4)" }, angle = 45 },
		layout = "dwindle",

        snap = {
            enabled = true,
            respect_gaps = true,
        },
	},

	decoration = {
		rounding = 15,

        shadow = {
            enabled = true,
            range = 4,
            color = "rgba(0,0,0,0.5)",
        },

		dim_special = 0.0,
		blur = {
			enabled = true,
            size = 5,
            passes = 3,
		},
	},

	-- animations.bezier / animations.animation are no longer config keys in
	-- 0.55+. Curves are declared with hl.curve(), individual animations with
	-- hl.animation(). The top-level enable flag is still here.
	animations = {
		enabled = true,
	},

	dwindle = {
		preserve_split = true,
	},

	scrolling = {
		column_width = 0.5,
		fullscreen_on_one_column = false,
		focus_fit_method = 1,
		follow_focus = true,
		follow_min_visible = 0.4,
		explicit_column_widths = "0.2, 0.25, 0.333, 0.5, 0.667, 1.0",
		direction = "left",
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		-- Suppress "started without start-hyprland" warning when using UWSM
		disable_watchdog_warning = true,
	},

	cursor = {
		enable_hyprcursor = true,
	},
})

-- Custom bezier curve (was: bezier = "myBezier, 0.05, 0.9, 0.1, 1.05")
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "slide top" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "default", style = "slidefadevert -50%" })
