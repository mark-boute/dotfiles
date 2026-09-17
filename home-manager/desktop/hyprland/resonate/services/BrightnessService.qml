pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// amdgpu_bl1 is always adjusted; nvidia_0 (this is a hybrid AMD iGPU +
// NVIDIA dGPU laptop, both of which expose a backlight device for the
// same physical panel) only when the dGPU isn't asleep — touching
// nvidia_0 while the card is asleep would needlessly wake it. The check
// reads `power/runtime_status` ("suspended"), NOT `power_state` — reading
// power_state on this driver *itself* resumes the card. Read back via
// amdgpu_bl1 alone, which is always available regardless of dGPU state.
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

  // Auto mode never dims the panel below this — the sun curve runs between
  // autoFloor (deep night) and 1.0 (full day) rather than 0.3..1.0.
  readonly property real autoFloor: 0.6;
  // Width of the sunset/sunrise dim, centred on the sun event. Linear (see
  // the `true` in applyAutoCurve): the panel walks one percent at a time,
  // evenly, across this whole window — no faster stretch in the middle.
  readonly property real autoTransitionHours: 2.0;
  // How fast a *discontinuous* auto change catches up (fraction/sec) — only
  // switching auto on or the first sync after startup ever moves far enough
  // to see this; a step of the transition above is a single percent and
  // lands in one tick.
  readonly property real autoRampRate: 0.2;

  Process {
    id: getProc;
    command: ["brightnessctl", "-d", "amdgpu_bl1", "-m", "i"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        var parts = (t || "").trim().split(",");
        var pct = parts.length >= 4 ? parseInt(parts[3]) : NaN;
        if (!isNaN(pct)) root.brightness = pct / 100;
        if (!root._haveReading) {
          root._haveReading = true;
          root.applyAutoCurve(); // now that we know the real level, fade to the curve
        }
      }
    }
  }
  Process { id: setProc; }

  // fromAuto: true for updates driven by the sun-curve timer below, so
  // they don't turn auto mode back off or flash the popup — every other
  // caller (a manual panel-slider drag, the popup's own drag/scroll, or
  // a keybind via adjust() below) leaves this at its default, and all of
  // those should both drop auto mode, stop any in-progress auto fade, and
  // flash the popup the same way.
  function setBrightness(fraction, fromAuto) {
    if (!fromAuto) {
      root.autoMode = false;
      rampTimer.stop();
      root.showOsd = true;
      osdTimer.restart();
    }
    root._writeHW(fraction);
  }

  // The actual backlight write, shared by manual sets and each step of the
  // auto fade.
  function _writeHW(fraction) {
    var pct = Math.round(Math.max(0, Math.min(1, fraction)) * 100);
    root.brightness = pct / 100; // optimistic, so callers don't wait on the next poll to catch up
    setProc.command = ["sh", "-c",
      "brightnessctl -d amdgpu_bl1 set " + pct + "% --min-value=1; " +
      "s=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null); " +
      "[ \"$s\" = suspended ] || brightnessctl -d nvidia_0 set " + pct + "% --min-value=1"];
    setProc.running = true;
  }

  property real _rampTarget: 1;
  property bool _haveReading: false; // getProc has returned at least once

  function applyAutoCurve() {
    if (!root.autoMode || !root._haveReading) return;
    root._rampTarget = Math.max(0, Math.min(1,
      SunService.curveValue(root.autoFloor, 1.0, root.autoTransitionHours, true)));

    var gap = Math.abs(root._rampTarget - root.brightness);
    if (gap <= 0.03) {
      // A transition step (or nothing) — the linear curve only moves ~0.3%
      // a minute, so just apply it the moment it rounds to a new percent.
      if (Math.round(root._rampTarget * 100) !== Math.round(root.brightness * 100))
        root._writeHW(root._rampTarget);
    } else if (!rampTimer.running) {
      // A real discontinuity (auto just switched on, first sync after
      // startup) — walk it down over a second or two instead of snapping.
      rampTimer.start();
    }
  }

  onAutoModeChanged: if (!root.autoMode) rampTimer.stop();

  // Walks root.brightness toward _rampTarget at autoRampRate for the
  // discontinuity cases only (auto switched on, first sync after startup) —
  // the sunset/sunrise transition itself is stepped a percent at a time
  // straight from applyAutoCurve. ~10Hz, not a frame-rate Behavior, so it
  // isn't spawning brightnessctl 60×/sec.
  Timer {
    id: rampTimer;
    interval: 100;
    repeat: true;
    onTriggered: {
      if (!root.autoMode) { rampTimer.stop(); return; }
      var step = root.autoRampRate * (rampTimer.interval / 1000);
      var d = root._rampTarget - root.brightness;
      if (Math.abs(d) <= step) {
        root._writeHW(root._rampTarget);
        rampTimer.stop();
      } else {
        root._writeHW(root.brightness + (d > 0 ? step : -step));
      }
    }
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

  // Rechecked every 30s: over a 2h linear window the target moves ~0.3%/min,
  // so this lands each 1% step within a few seconds of when it's due.
  Timer {
    interval: 30000;
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
