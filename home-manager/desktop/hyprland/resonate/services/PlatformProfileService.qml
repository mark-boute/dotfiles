pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// ACPI platform profile (Legion firmware fan/TDP curves). The sysfs attr is
// opened to the `users` group by a tmpfiles rule in
// hosts/legion/nixos-hardware.nix, so this writes it directly.
//
// IMPORTANT: reading /sys/firmware/acpi/platform_profile invokes the Legion
// GameZone WMI method, which resumes the NVIDIA dGPU (~2s D0, several watts).
// So this reads it exactly once at startup and once after each write it
// makes — never on a timer. The value only changes when we change it.
//
// autoMode picks low-power on battery / balanced on AC — same shape as
// BrightnessService: any manual pick switches it off until the next
// AC<->battery transition.
Singleton {
  id: root;

  readonly property var profiles: ["low-power", "balanced", "performance"];
  readonly property string path: "/sys/firmware/acpi/platform_profile";

  property string profile: "balanced";
  property bool autoMode: true;
  property bool available: false;     // true once the sysfs attr reads back
  property bool _primed: false;

  function set(name, fromAuto) {
    if (root.profiles.indexOf(name) < 0)
      return;
    if (!fromAuto)
      root.autoMode = false;
    root.profile = name;
    writeProc.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", name, root.path];
    writeProc.running = true;
  }

  function applyAuto() {
    if (!root.autoMode)
      return;
    root.set(UPower.onBattery ? "low-power" : "balanced", true);
  }
  onAutoModeChanged: if (autoMode) applyAuto();

  Connections {
    target: UPower;
    function onOnBatteryChanged() { root.applyAuto(); }
  }

  Process {
    id: writeProc;
    onExited: readProc.running = true;   // confirm what actually stuck
  }

  Process {
    id: readProc;
    command: ["cat", root.path];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        var v = (t || "").trim();
        if (root.profiles.indexOf(v) >= 0) {
          root.available = true;
          root.profile = v;
        }
        if (!root._primed) {
          root._primed = true;
          root.applyAuto();
        }
      }
    }
  }

  Component.onCompleted: readProc.running = true;
}
