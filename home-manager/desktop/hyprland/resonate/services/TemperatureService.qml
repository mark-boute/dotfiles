pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// hyprsunset (already running as a daemon — see hypr/exec.lua) has no
// "get current value" IPC call, only ways to set one, so this service is
// the *only* record of the real current value — there's no polling to
// fall back on the way BrightnessService has. That's exactly why the
// temperature keybinds (hypr/keybinds.lua) call into this service's
// IpcHandler instead of running `hyprctl hyprsunset temperature +250`
// directly: if they didn't, this service's temperatureK would drift out
// of sync with hyprsunset's actual state the first time a keybind fired.
// Defaulted to hyprsunset's own documented default (6000K) since it's
// launched with no --temperature flag.
Singleton {
  id: root;

  property int temperatureK: 6000;
  readonly property int minTempK: 2500;
  readonly property int maxTempK: 6500;
  property bool autoMode: true;
  property bool showOsd: false;

  Process { id: setProc; }

  // fromAuto: true for updates driven by the sun-curve timer below, so
  // they don't turn auto mode back off or flash the popup — every other
  // caller (a manual panel-slider drag, the popup's own drag/scroll, or
  // a keybind via adjust() below) leaves this at its default, and all of
  // those should both drop auto mode and flash the popup the same way.
  function setTemperature(fraction, fromAuto) {
    if (!fromAuto) {
      root.autoMode = false;
      root.showOsd = true;
      osdTimer.restart();
    }
    var k = Math.round(minTempK + Math.max(0, Math.min(1, fraction)) * (maxTempK - minTempK));
    root.temperatureK = k;
    setProc.command = ["hyprctl", "hyprsunset", "temperature", String(k)];
    setProc.running = true;
  }

  function applyAutoCurve() {
    if (root.autoMode) {
      var k = SunService.curveValue(root.minTempK + 900, root.maxTempK, 1.5);
      root.setTemperature((k - root.minTempK) / (root.maxTempK - root.minTempK), true);
    }
  }

  // Adjusts by a relative Kelvin delta (matching the old +250/-250
  // keybind convention) — setTemperature itself flashes the popup.
  function adjust(deltaK) {
    var k = Math.max(minTempK, Math.min(maxTempK, root.temperatureK + deltaK));
    setTemperature((k - minTempK) / (maxTempK - minTempK));
  }

  // Rechecked every minute — fine-grained enough that SunService's eased
  // transition around sunrise/sunset still reads as smooth.
  Timer {
    interval: 60000;
    repeat: true;
    running: true;
    triggeredOnStart: true;
    onTriggered: root.applyAutoCurve();
  }

  Timer {
    id: osdTimer;
    interval: 2000;
    onTriggered: root.showOsd = false;
  }

  IpcHandler {
    target: "temperature";
    function adjust(deltaK: string): void {
      root.adjust(parseInt(deltaK) || 0);
    }
  }
}
