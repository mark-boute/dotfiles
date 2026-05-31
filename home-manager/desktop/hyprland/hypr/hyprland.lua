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

-- Per-user or host overrides added to .config/hypr.
try_require("monitors")

-- Shared configuration files.
require("keybinds").register()
require("appearance")
require("input")

-- Startup commands, optionally feeds qs config path for per-host overrides.
require("exec")(try_require("qs-config"))
