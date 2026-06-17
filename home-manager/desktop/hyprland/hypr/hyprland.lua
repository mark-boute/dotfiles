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

-- hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", os.getenv("QT_AUTO_SCREEN_SCALE_FACTOR") or "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", os.getenv("QT_WAYLAND_DISABLE_WINDOWDECORATION") or "1")
hl.env("QT_QPA_PLATFORMTHEME", os.getenv("QT_QPA_PLATFORMTHEME") or "qt5ct")
hl.env("QT_STYLE_OVERRIDE", os.getenv("QT_STYLE_OVERRIDE") or "adwaita-dark")

hl.env("GTK_THEME", "catppuccin-macchiato-rosewater-standard-default")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.config({ xwayland = { force_zero_scaling = true } })

-- Per-user or host overrides added to .config/hypr.
try_require("monitors")
try_require("nvidia")

-- Shared configuration files.
require("keybinds").register()
require("appearance")
require("input")

-- Startup commands, optionally feeds qs config path for per-host overrides.
require("exec")(try_require("qs-config"))
