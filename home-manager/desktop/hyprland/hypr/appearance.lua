hl.config({
	general = {
		gaps_in = 2,
		gaps_out = {top = 0, left = 5, bottom = 5, right = 5},
        gaps_workspaces = 50;
		border_size = 2,
        resize_on_border = true,

		["col.active_border"] = { colors = { "rgba(245, 169, 127, 1)", "rgba(244,219,214,1)" }, angle = 45 },
		["col.inactive_border"] = { colors = { "rgba(245, 169, 127, .4)", "rgba(244,219,214,0.4)" }, angle = 135 },
		layout = "dwindle",

        snap = {
            enabled = true,
            respect_gaps = true,
        },
	},

	decoration = {
		rounding = 15,

        shadow = {
            enabled = false,
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

-- Frosted-glass bar/panels: resonate's own translucent surface color (see
-- CurrentTheme.qml) only reads as "glass" once there's real blur behind it.
-- ignore_alpha excludes the mostly-transparent bar window's empty space
-- (alpha 0) from the blur, so only the actual pill/panel shapes (alpha
-- ~0.72) get it — without this, the whole window's bounding box blurs,
-- which is most of the screen width once a panel is open.
--
-- Kept above the drop shadow's peak alpha (Theme.shadowColor, 0.45) on
-- purpose: Hyprland's blur region is a bounding rect, not the pill's actual
-- rounded shape, so if the shadow's soft gradient qualified too, the blur
-- region would extend into the shadow's (rectangular) texture bounds and
-- show up as a faint square edge around each pill instead of following its
-- silhouette.
hl.layer_rule({ match = { namespace = "quickshell:resonate:bar" }, blur = true, ignore_alpha = 0.5 })
