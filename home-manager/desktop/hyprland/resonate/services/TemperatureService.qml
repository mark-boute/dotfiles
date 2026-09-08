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

  // Auto mode's evening target — warm but not the full 2500K floor, leaving
  // manual headroom. Day target is maxTempK.
  readonly property int autoNightK: 3400;
  // Width of the sunset/sunrise shift, centred on the sun event, walked
  // linearly (see the `true` in applyAutoCurve): the temperature crawls a
  // few Kelvin at a time, evenly, across the whole window — matches
  // BrightnessService.autoTransitionHours.
  readonly property real autoTransitionHours: 2.0;
  // How fast a discontinuity (auto just switched on) catches up, as a
  // fraction of the K range per second — only ever seen on that toggle.
  readonly property real autoRampRate: 0.2;

  Process { id: setProc; }

  function _kToFrac(k) { return (k - root.minTempK) / (root.maxTempK - root.minTempK); }
  function _fracToK(f) { return Math.round(root.minTempK + Math.max(0, Math.min(1, f)) * (root.maxTempK - root.minTempK)); }

  // fromAuto: true for updates driven by the sun-curve timer below, so
  // they don't turn auto mode back off, stop the auto ramp, or flash the
  // popup — every other caller (a manual panel-slider drag, the popup's own
  // drag/scroll, or a keybind via adjust() below) leaves this at its
  // default, and all of those should do all three.
  function setTemperature(fraction, fromAuto) {
    if (!fromAuto) {
      root.autoMode = false;
      rampTimer.stop();
      root.showOsd = true;
      osdTimer.restart();
    }
    root._writeK(root._fracToK(fraction));
  }

  // The actual hyprsunset write, shared by manual sets and each auto step.
  function _writeK(k) {
    root.temperatureK = k;
    setProc.command = ["hyprctl", "hyprsunset", "temperature", String(k)];
    setProc.running = true;
  }

  property real _rampTargetFrac: 1;
  property bool _primed: false; // first auto sync has run

  function applyAutoCurve() {
    if (!root.autoMode) return;
    root._rampTargetFrac = Math.max(0, Math.min(1, root._kToFrac(
      SunService.curveValue(root.autoNightK, root.maxTempK, root.autoTransitionHours, true))));

    if (!root._primed) {
      // No readback exists for hyprsunset, so there's no real prior value to
      // ease from on the first sync — just set it.
      root._primed = true;
      root._writeK(root._fracToK(root._rampTargetFrac));
      return;
    }

    var gap = Math.abs(root._rampTargetFrac - root._kToFrac(root.temperatureK));
    if (gap <= 0.03) {
      // A transition step — the linear curve moves ~25K/min, so just apply
      // the new value each 30s tick.
      var k = root._fracToK(root._rampTargetFrac);
      if (k !== root.temperatureK) root._writeK(k);
    } else if (!rampTimer.running) {
      // A discontinuity (auto just switched on) — crawl to it, don't snap.
      rampTimer.start();
    }
  }

  onAutoModeChanged: if (!root.autoMode) rampTimer.stop();

  // Walks temperatureK toward _rampTargetFrac at autoRampRate for the
  // auto-switched-on case only; the sun transition itself is stepped
  // straight from applyAutoCurve.
  Timer {
    id: rampTimer;
    interval: 100;
    repeat: true;
    onTriggered: {
      if (!root.autoMode) { rampTimer.stop(); return; }
      var cur = root._kToFrac(root.temperatureK);
      var step = root.autoRampRate * (rampTimer.interval / 1000);
      var d = root._rampTargetFrac - cur;
      if (Math.abs(d) <= step) {
        root._writeK(root._fracToK(root._rampTargetFrac));
        rampTimer.stop();
      } else {
        root._writeK(root._fracToK(cur + (d > 0 ? step : -step)));
      }
    }
  }

  // Adjusts by a relative Kelvin delta (matching the old +250/-250
  // keybind convention) — setTemperature itself flashes the popup.
  function adjust(deltaK) {
    var k = Math.max(minTempK, Math.min(maxTempK, root.temperatureK + deltaK));
    setTemperature(_kToFrac(k));
  }

  // Rechecked every 30s so each small linear step of the transition lands
  // close to when it's due (same cadence as BrightnessService).
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
    target: "temperature";
    function adjust(deltaK: string): void {
      root.adjust(parseInt(deltaK) || 0);
    }
  }
}
