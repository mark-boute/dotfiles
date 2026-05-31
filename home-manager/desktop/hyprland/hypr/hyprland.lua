local HOME = os.getenv("HOME")
local XDG = os.getenv("XDG_CONFIG_HOME") or (HOME .. "/.config")
local PUBLIC = XDG .. "/hypr"

package.path = package.path
  .. ";" .. PUBLIC .. "/?.lua"


local function try_require(name)
  if package.searchpath(name, package.path) then
    return require(name)
  end
  return nil
end

hl.config({
	debug = {
		disable_logs = true,
	},
})

require("keybinds").register()
require("appearance")
require("input")
try_require("monitors")
require("exec")(try_require("qs-config"))
