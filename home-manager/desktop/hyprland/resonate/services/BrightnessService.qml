pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// amdgpu_bl1 is always adjusted; nvidia_0 (this is a hybrid AMD iGPU +
// NVIDIA dGPU laptop, both of which expose a backlight device for the
// same physical panel) only when the dGPU isn't asleep — matching the
// original brightness keybinds, for the same D3cold-check reason as the
// GPU-draw probe elsewhere: touching nvidia_0 while the card is asleep
// would needlessly wake it. Read back via amdgpu_bl1 alone, which is
// always available regardless of dGPU state.
//
// A singleton (not local panel state) so PowerPanel's slider and
// PowerStatus's OSD both read the same live value, and so the
// IpcHandler below — which the brightness keybinds call into instead of
// running brightnessctl directly (see hypr/keybinds.lua) — exists
// independent of whether any panel has ever been opened.
Singleton {
  id: root;

  property real brightness: 1; // 0..1
  // No ambient light sensor exists on this machine (checked both
  // iio-sensor-proxy and raw /sys/bus/iio/devices — neither is present),
  // so "auto" here means the same sun-driven time-of-day curve as
  // TemperatureService, not an actual light reading.
  property bool autoMode: true;
  property bool showOsd: false;

  Process {
    id: getProc;
    command: ["brightnessctl", "-d", "amdgpu_bl1", "-m", "i"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        var parts = (t || "").trim().split(",");
        var pct = parts.length >= 4 ? parseInt(parts[3]) : NaN;
        if (!isNaN(pct)) root.brightness = pct / 100;
      }
    }
  }
  Process { id: setProc; }

  // fromAuto: true for updates driven by the sun-curve timer below, so
  // they don't turn auto mode back off or flash the popup — every other
  // caller (a manual panel-slider drag, the popup's own drag/scroll, or
  // a keybind via adjust() below) leaves this at its default, and all of
  // those should both drop auto mode and flash the popup the same way.
  function setBrightness(fraction, fromAuto) {
    if (!fromAuto) {
      root.autoMode = false;
      root.showOsd = true;
      osdTimer.restart();
    }
    var pct = Math.round(Math.max(0, Math.min(1, fraction)) * 100);
    root.brightness = pct / 100; // optimistic, so callers don't wait on the next poll to catch up
    setProc.command = ["sh", "-c",
      "brightnessctl -d amdgpu_bl1 set " + pct + "% --min-value=1; " +
      "s=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null); " +
      "[ \"$s\" = D3cold ] || brightnessctl -d nvidia_0 set " + pct + "% --min-value=1"];
    setProc.running = true;
  }

  function applyAutoCurve() {
    if (root.autoMode) root.setBrightness(SunService.curveValue(0.3, 1.0, 1.5), true);
  }

  // Adjusts by a relative percentage (matching brightnessctl's own
  // N%+/N%- convention) — used by the brightness keybinds via IPC, so
  // resonate (not the keybind) is what actually knows and sets the
  // resulting value. setBrightness itself flashes the popup.
  function adjust(deltaPercent) {
    setBrightness(root.brightness + deltaPercent / 100);
  }

  Timer {
    interval: 2000;
    repeat: true;
    running: true;
    triggeredOnStart: true;
    onTriggered: getProc.running = true;
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
    target: "brightness";
    function adjust(deltaPercent: string): void {
      root.adjust(parseFloat(deltaPercent) || 0);
    }
  }
}
