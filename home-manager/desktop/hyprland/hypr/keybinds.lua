-- All Hyprland keybinds. Flat list, comments mark logical sections.
-- Also consumed by menu.lua to render the rofi keybind viewer (SUPER + /).
--
-- Each bind has an `action` table describing what it does:
--   { exec = "shell command" }                        -- via hl.dsp.exec_cmd
--   { dispatch = function() return hl.dsp.* end }     -- builds a dispatcher
--   { fn       = function() ... end }                 -- raw lua callback
--
-- Storing actions as data means this file loads in plain Lua too: menu.lua
-- can `require("keybinds")` without `hl` being defined. M.register() at the
-- bottom is what calls hl.* (only when hl is present).
--
-- Per-host extras (e.g. nt-oryx System76 menu) live in device-keybinds.lua
-- and append/mutate M.binds before M.register() runs.

local M = {}

-- Native-Lua action implementations (multi-step / state-holding). Loaded
-- lazily via require so this file still parses when run by menu.lua.
local actions = nil
local function ensure_actions()
	if actions == nil and hl then
		actions = require("actions")
	end
	return actions
end

-- Action helpers. Cheap to evaluate without `hl` because they only build data;
-- the function members are evaluated lazily inside register().
local A = {}
A.exec = function(c)
	return { exec = c }
end

A.exec_app = function(c)
	return { exec = "systemd-run --user --scope --slice=app.slice " .. c }
end
A.global = function(c)
	return {
		dispatch = function()
			return hl.dsp.global(c)
		end,
	}
end
A.kill = function()
	return {
		dispatch = function()
			return hl.dsp.window.kill()
		end,
	}
end
A.toggle_float = function()
	return {
		dispatch = function()
			return hl.dsp.window.float()
		end,
	}
end
A.fullscreen = function(mode)
	return {
		dispatch = function()
			return hl.dsp.window.fullscreen({ mode = mode })
		end,
	}
end
A.pin = function()
	return {
		dispatch = function()
			return hl.dsp.window.pin()
		end,
	}
end
A.focus_dir = function(d)
	return {
		dispatch = function()
			return hl.dsp.focus({ direction = d })
		end,
	}
end
A.swap_dir = function(d)
	return {
		dispatch = function()
			return hl.dsp.window.swap({ direction = d })
		end,
	}
end
A.move_xy = function(x, y)
	return {
		dispatch = function()
			return hl.dsp.window.move({ x = x, y = y, relative = true })
		end,
	}
end
A.resize_xy = function(x, y)
	return {
		dispatch = function()
			return hl.dsp.window.resize({ x = x, y = y, relative = true })
		end,
	}
end
A.focus_ws = function(n)
	return {
		dispatch = function()
			return hl.dsp.focus({ workspace = n })
		end,
	}
end
A.move_ws_silent = function(n)
	return {
		dispatch = function()
			return hl.dsp.window.move({ workspace = n, follow = false })
		end,
	}
end
A.toggle_special = function(n)
	return {
		dispatch = function()
			return hl.dsp.workspace.toggle_special(n)
		end,
	}
end
A.layout = function(m)
	return {
		dispatch = function()
			return hl.dsp.layout(m)
		end,
	}
end
A.drag = function()
	return {
		dispatch = function()
			return hl.dsp.window.drag()
		end,
	}
end
A.mresize = function()
	return {
		dispatch = function()
			return hl.dsp.window.resize()
		end,
	}
end
A.float_and_pin = function()
	return {
		fn = function()
			hl.dispatch(hl.dsp.window.float())
			hl.dispatch(hl.dsp.window.pin())
		end,
	}
end

-- Native-Lua helpers from actions.lua (replace the old hypr-* shell scripts).
A.reset_splits = function()
	return {
		fn = function()
			ensure_actions().reset_splits()
		end,
	}
end
A.dwindle_resize = function(d)
	return {
		fn = function()
			ensure_actions().dwindle_resize(d)
		end,
	}
end
A.resize_step = function(d)
	return {
		fn = function()
			ensure_actions().resize_step(d)
		end,
	}
end
A.colresize_all = function(d)
	return {
		fn = function()
			ensure_actions().colresize_all(d)
		end,
	}
end
A.toggle_special_move = function(n)
	return {
		fn = function()
			ensure_actions().toggle_special_move(n)
		end,
	}
end

M.binds = {
	-- Applications
	{ keys = "SUPER + T", desc = "Open Kitty terminal", action = A.exec_app("kitty") },
	{ keys = "SUPER + Space", desc = "Run launcher", action = A.exec_app("hyprlauncher") },
	{ keys = "SUPER + W", desc = "Open Browser", action = A.exec_app("zen-beta") },
	{ keys = "SUPER + E", desc = "Open File Explorer", action = A.exec_app("nautilus") },
    { keys = "SUPER + C", desc = "Open VSCode", action = A.exec_app("code") },
    { keys = "SUPER + U", desc = "Open Authenticator", action = A.exec_app("authenticator") },
    { keys = "SUPER + D", desc = "Open Discord", action = A.exec_app("discord") },

    -- Window management
    { keys = "SUPER + Q", desc = "Close focused window", action = A.kill() },
    {
		keys = "SUPER + SHIFT + Q",
		desc = "Force kill active window",
		action = A.exec("kill -9 $(hyprctl activewindow -j | jq -r '.pid')"),
	},
	{ keys = "SUPER + F", desc = "Fullscreen", action = A.fullscreen("fullscreen") },
	{ keys = "SUPER + SHIFT + F", desc = "Fake fullscreen", action = A.fullscreen("maximized") },

	-- Mouse
	{ keys = "SUPER + mouse:272", desc = "Move window (left click drag)", action = A.drag(), mouse = true },
	{ keys = "SUPER + mouse:273", desc = "Resize window (right click drag)", action = A.mresize(), mouse = true },

	-- Window resize & move
	{ keys = "SUPER + left", desc = "Move floating window left", action = A.move_xy(-20, 0), repeating = true },
	{ keys = "SUPER + right", desc = "Move floating window right", action = A.move_xy(20, 0), repeating = true },
	{ keys = "SUPER + up", desc = "Move floating window up", action = A.move_xy(0, -60), repeating = true },
	{ keys = "SUPER + down", desc = "Move floating window down", action = A.move_xy(0, 60), repeating = true },

	{ keys = "SUPER + ALT + h", desc = "Shrink window to previous breakpoint", action = A.resize_step("down") },
	{ keys = "SUPER + ALT + l", desc = "Grow window to next breakpoint", action = A.resize_step("up") },
	{ keys = "SUPER + ALT + k", desc = "Resize window up", action = A.resize_xy(0, -20), repeating = true },
	{ keys = "SUPER + ALT + j",	desc = "Resize window down", action = A.resize_xy(0, 20), repeating = true },

	-- Window navigation
	{ keys = "SUPER + H", desc = "Focus window left", action = A.focus_dir("l") },
	{ keys = "SUPER + L", desc = "Focus window right", action = A.focus_dir("r") },
	{ keys = "SUPER + K", desc = "Focus window up", action = A.focus_dir("u") },
	{ keys = "SUPER + J", desc = "Focus window down", action = A.focus_dir("d") },
	{ keys = "SUPER + SHIFT + H", desc = "Swap window left", action = A.swap_dir("l") },
	{ keys = "SUPER + SHIFT + L", desc = "Swap window right", action = A.swap_dir("r") },
	{ keys = "SUPER + SHIFT + K", desc = "Swap window up", action = A.swap_dir("u") },
	{ keys = "SUPER + SHIFT + J", desc = "Swap window down", action = A.swap_dir("d") },

    -- Workspace management
    { keys = "SUPER + Tab", desc = "Switch to previous workspace on monitor", action = A.focus_ws("previous_on_monitor") },
	{ keys = "SUPER + SHIFT + Tab", desc = "Move to previous workspace", action = A.focus_ws("previous") },
	{ keys = "SUPER + Grave", desc = "Create new workspace on current monitor", action = A.focus_ws("emptynm") },
	{ keys = "SUPER + SHIFT + Grave", desc = "Create new workspace", action = A.focus_ws("emptyn") },
	{ keys = "SUPER + mouse_up", desc = "Switch to next workspace (mouse)", action = A.focus_ws("r-1"), mouse = true },
	{ keys = "SUPER + mouse_down", desc = "Switch to previous workspace (mouse)", action = A.focus_ws("r+1"), mouse = true },

    -- System
	{ keys = "SUPER + ALT + R", desc = "Reload Hyprland", action = A.exec("hyprctl reload") },
	{ keys = "SUPER + Escape", desc = "Lock screen", action = A.global("quickshell:Lock") },
	{ keys = "SUPER + SHIFT + Escape", desc = "Log out", action = A.exec("hyprshutdown -t 'Logging out...' --post-cmd 'hyprctl dispatch exit'") },
    {
		keys = "SUPER + SHIFT + Delete",
		desc = "Reboot system",
		action = A.exec("hyprshutdown -t 'Restarting...' --post-cmd 'reboot'")
	},
    {
		keys = "SUPER + Delete",
		desc = "Power off system",
		action = A.exec("hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'"),
		{locked = true}
	},

	-- Screenshots
    { keys = "SUPER + SHIFT + S", desc = "Screenshot (region)",  action = A.exec("hyprshot -m region -o ~/Pictures/Screenshots") },
    { keys = "PRINT",             desc = "Screenshot (output)",  action = A.exec("hyprshot -m output -o ~/Pictures/Screenshots") },
    { keys = "SUPER + PRINT",     desc = "Screenshot (window)",  action = A.exec("hyprshot -m window -o ~/Pictures/Screenshots") },

	-- Volume keys
	{ keys = "XF86AudioMute", desc = "Toggle mute", action = A.exec("pamixer --toggle-mute") },
	{ keys = "XF86AudioLowerVolume", desc = "Lower volume", action = A.exec("pamixer --decrease 5"), repeating = true },
	{ keys = "XF86AudioRaiseVolume", desc = "Raise volume", action = A.exec("pamixer --increase 5"), repeating = true },

	-- Brightness and color temperature keys
	-- Note: if brightnessctl doesn't control your backlight (e.g. NVIDIA routing
	-- issue), revert to the hyprsunset gamma approach below:
	--   A.exec("hyprctl hyprsunset gamma +10")  /  A.exec("hyprctl hyprsunset gamma -10")
	{
		keys = "XF86MonBrightnessUp",
		desc = "Increase brightness",
		action = A.exec("brightnessctl set 5%+ --min-value=1"),
		repeating = true,
	},
	{
		keys = "XF86MonBrightnessDown",
		desc = "Decrease brightness",
		action = A.exec("brightnessctl set 5%- --min-value=1"),
		repeating = true,
	},
    {
        keys = "SUPER + XF86MonBrightnessUp",
        desc = "Increase temperature",
        action = A.exec("hyprctl hyprsunset temperature +250"),
        repeating = true,
    },
    {
        keys = "SUPER + XF86MonBrightnessDown",
        desc = "Decrease temperature",
        action = A.exec("hyprctl hyprsunset temperature -250"),
        repeating = true,
    },
}

for i = 1, 10 do
    local key = tostring(i % 10) -- 10 maps to key '0'
    
    -- Switch to workspace i
    table.insert(M.binds, {
        keys = "SUPER + " .. key,
        desc = "Switch to workspace " .. i,
        action = A.focus_ws(i)
    })
    
    -- Move to workspace i (silently)
    table.insert(M.binds, {
        keys = "SUPER + SHIFT + " .. key,
        desc = "Move to workspace " .. i,
        action = A.move_ws_silent(i)
    })
end

-- Build a dispatcher (or callback) from an action table.
-- Called lazily so this module can load without `hl` defined.
local function build(action)
	if action.exec then
		return hl.dsp.exec_cmd(action.exec)
	end
	if action.dispatch then
		return action.dispatch()
	end
	if action.fn then
		return action.fn
	end
	error("keybinds: action with no exec/dispatch/fn field")
end

-- Register every bind via hl.bind. Run AFTER device-keybinds has had a chance
-- to mutate or append to M.binds.
function M.register()
	if not hl then
		return
	end
	for _, b in ipairs(M.binds) do
		local flags = { description = b.desc }
		if b.repeating then
			flags.repeating = true
		end
		if b.mouse then
			flags.mouse = true
		end
		if b.locked then
			flags.locked = true
		end
		hl.bind(b.keys, build(b.action), flags)
	end
end

M.A = A
return M

	-- {
	-- 	keys = "SUPER + i",
	-- 	desc = "Notes scratchpad",
	-- 	action = A.exec_app("pypr-toggle-smart notes"),
	-- },
	-- {
	-- 	keys = "SUPER + SHIFT + i",
	-- 	desc = "Send window to notes scratchpad",
	-- 	action = A.move_ws_silent("special:scratch_notes"),
	-- },
	-- {
	-- 	keys = "SUPER + ALT + i",
	-- 	desc = "Lockbook file menu",
	-- 	action = A.exec_app("lockbook-menu"),
	-- },
	-- {
	-- 	keys = "SUPER + o",
	-- 	desc = "File manager scratchpad",
	-- 	action = A.exec_app("pypr-toggle-smart files"),
	-- },
	-- {
	-- 	keys = "SUPER + SHIFT + o",
	-- 	desc = "Send window to file manager scratchpad",
	-- 	action = A.move_ws_silent("special:scratch_files"),
	-- },
	-- {
	-- 	keys = "SUPER + y",
	-- 	desc = "Toggle chat workspace",
	-- 	action = A.toggle_special("chat"),
	-- },
	-- {
	-- 	keys = "SUPER + SHIFT + y",
	-- 	desc = "Send window to chat workspace",
	-- 	action = A.move_ws_silent("special:chat"),
	-- },
	-- {
	-- 	keys = "SUPER + SHIFT + semicolon",
	-- 	desc = "Toggle scratch workspace",
	-- 	action = A.toggle_special("scratch"),
	-- },
	-- {
	-- 	keys = "SUPER + v",
	-- 	desc = "Clipboard history",
	-- 	action = A.exec(
	-- 		"cliphist list | rofi -dmenu -theme-str 'window { width: 800px; }' | cliphist decode | wl-copy"
	-- 	),
	-- },
	-- {
	-- 	keys = "SUPER + z",
	-- 	desc = "Magnify/zoom current window",
	-- 	action = A.exec("pypr zoom"),
	-- },

	-- -- Layout helpers
	-- {
	-- 	keys = "SUPER + semicolon",
	-- 	desc = "Toggle scrolling/dwindle layout",
	-- 	action = A.exec("hypr-toggle-layout"),
	-- },
	-- {
	-- 	keys = "SUPER + ALT + semicolon",
	-- 	desc = "Toggle center/fit focus (scrolling)",
	-- 	action = A.exec("hypr-toggle-center-focus"),
	-- },
	-- {
	-- 	keys = "SUPER + SHIFT + apostrophe",
	-- 	desc = "Fit all columns on screen",
	-- 	action = A.layout("fitsize all"),
	-- },
	-- {
	-- 	keys = "SUPER + CTRL + h",
	-- 	desc = "Shrink all columns one step",
	-- 	action = A.colresize_all("down"),
	-- },
	-- {
	-- 	keys = "SUPER + CTRL + l",
	-- 	desc = "Grow all columns one step",
	-- 	action = A.colresize_all("up"),
	-- },
	-- {
	-- 	keys = "SUPER + s",
	-- 	desc = "Toggle split direction (dwindle)",
	-- 	action = A.layout("togglesplit"),
	-- },
	-- {
	-- 	keys = "SUPER + x",
	-- 	desc = "Swap column right",
	-- 	action = A.layout("swapsplit"),
	-- },
	-- {
	-- 	keys = "SUPER + ALT + m",
	-- 	desc = "Move window to root (dwindle)",
	-- 	action = A.layout("movetoroot"),
	-- },
	-- { keys = "SUPER + apostrophe", desc = "Reset all splits to 50/50 (dwindle)", action = A.reset_splits() },

	-- -- Utilities
	-- { keys = "SUPER + SHIFT + w", desc = "Wallpaper menu", action = A.exec_app("rofi-wallpaper-menu") },
	-- {
	-- 	keys = "SUPER + SHIFT + b",
	-- 	desc = "Randomize waybar gradient",
	-- 	action = A.exec("systemctl --user restart waybar-gradient-randomizer"),
	-- },
	-- { keys = "SUPER + n", desc = "VPN menu", action = A.exec_app("rofi-vpn-menu") },
	-- { keys = "CTRL + ALT + l", desc = "Lock screen", action = A.exec_app("hyprlock") },
	-- { keys = "SUPER + ALT + c", desc = "Color picker", action = A.exec_app("hyprpicker -a") },
	-- { keys = "SUPER + ALT + s", desc = "Notify shares", action = A.exec("notify-shares") },
	-- { keys = "SUPER + ALT + p", desc = "Screenshot menu", action = A.exec_app("rofi-screenshot-menu") },
	-- { keys = "SUPER + SHIFT + p", desc = "Screenshot (region)", action = A.exec("smart-screenshot region") },
	-- { keys = "SUPER + r", desc = "Toggle screen recording", action = A.exec("toggle-recording") },

	-- -- Widgets
	-- { keys = "SUPER + b", desc = "Toggle EWW dashboard", action = A.exec_app("eww open --toggle dashboard") },
