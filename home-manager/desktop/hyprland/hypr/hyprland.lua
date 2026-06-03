local HOME = os.getenv("HOME")
local XDG = os.getenv("XDG_CONFIG_HOME") or (HOME .. "/.config")
local PUBLIC = XDG .. "/hypr"

package.path = package.path
  .. ";" .. PUBLIC .. "/?.lua"

hl.config({
	debug = {
		disable_logs = true,
	},
})

local function try_require(name)
  local ok, module = pcall(require, name)
  return ok and module or nil
end

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

-- Per-user or host overrides added to .config/hypr.
try_require("monitors")
try_require("nvidia")

-- Shared configuration files.
require("keybinds").register()
require("appearance")
require("input")

-- Startup commands, optionally feeds qs config path for per-host overrides.
require("exec")(try_require("qs-config"))
