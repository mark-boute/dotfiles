pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Hyprland
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
// autoMode picks low-power on battery, balanced on AC, and performance on AC
// while a window is fullscreen on any monitor (games; debounced 5s so a
// quick fullscreen video toggle doesn't flip it) — same shape as
// BrightnessService: any manual pick switches it off until auto is picked again.
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
    var target = UPower.onBattery ? "low-power" : (root.fullscreen ? "performance" : "balanced");
    // Skip no-op writes: each one is read back, which briefly wakes the dGPU.
    if (target !== root.profile)
      root.set(target, true);
  }
  onAutoModeChanged: if (autoMode) applyAuto();

  readonly property bool _anyFullscreen: {
    var ms = Hyprland.monitors.values;
    for (var i = 0; i < ms.length; i++) {
      var ws = ms[i].activeWorkspace;
      if (ws && ws.hasFullscreen) return true;
    }
    return false;
  }
  property bool fullscreen: false; // _anyFullscreen, held for 5s before it counts
  on_AnyFullscreenChanged: fullscreenSettle.restart();
  Timer {
    id: fullscreenSettle;
    interval: 5000;
    onTriggered: root.fullscreen = root._anyFullscreen;
  }
  onFullscreenChanged: applyAuto();

  Connections {
    target: UPower;
    function onOnBatteryChanged() { root.applyAuto(); }
  }

  // Hardware video decode follows the profile: NVDEC only in performance,
  // the iGPU's VA-API otherwise so playback doesn't wake the dGPU. Apps read
  // this at start, so it reaches newly launched apps only — via Hyprland,
  // D-Bus/systemd activation, and launchCommand() for resonate's launcher.
  readonly property string libvaDriver: root.profile === "performance" ? "nvidia" : "radeonsi";
  onLibvaDriverChanged: root._applyLibva();
  function _applyLibva() {
    Quickshell.execDetached(["hyprctl", "eval", 'hl.env("LIBVA_DRIVER_NAME", "' + root.libvaDriver + '")']);
    Quickshell.execDetached(["dbus-update-activation-environment", "--systemd", "LIBVA_DRIVER_NAME=" + root.libvaDriver]);
  }
  function launchCommand(command, workingDirectory) {
    var c = ["env"];
    if (workingDirectory)
      c.push("-C", workingDirectory);
    c.push("LIBVA_DRIVER_NAME=" + root.libvaDriver);
    return c.concat(command);
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

  IpcHandler {
    target: "profile";
    function set(name: string): void { root.set(name); }
    function auto(): void { root.autoMode = true; }
    function get(): string { return (root.autoMode ? "auto:" : "") + root.profile; }
  }

  Component.onCompleted: {
    readProc.running = true;
    root._applyLibva();
  }
}
