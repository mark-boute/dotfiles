pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import qs

// Backs the ControlPanel's Lights app (WOOX/Tuya bulbs + WiZ devices,
// controlled locally — see scripts/lights_ctl.py and Config.lightsDevicesFile).
// Structurally mirrors ChecklistService.qml: a poll Process parses JSON from
// stdout, writes are debounced/coalesced through a single-flight queue.
//
// `reachable` (any bulb answering on the LAN) is deliberately the *only*
// "am I home" signal resonate uses — no separate gateway/router detection.
// AppDrawer's Lights tile binds straight to it.
Singleton {
  id: root;

  property var devices: [];          // [{id, name, caps:[...], reachable, on, brightness(0..1), temperature(0..1), rgb:[r,g,b]}]
  readonly property bool reachable: devices.some((d) => d.reachable);
  property bool configured: false;   // Config.lightsDevicesFile exists & non-empty
  property bool loading: false;
  property string error: "";
  property int revision: 0;          // device set changed (rare)
  property int statusRevision: 0;    // any poll landing or local optimistic edit

  // LightsApp.qml toggles this on open/close — drives the fast poll interval.
  property bool appActive: false;
  // SliderPill/ColorWheel toggle this while dragging — polling is paused so a
  // response mid-drag can't yank a handle back to the last-known server value.
  property bool dragActive: false;

  property string _lastIds: "";

  function _findDevice(id) {
    for (var i = 0; i < devices.length; i++)
      if (devices[i].id === id) return devices[i];
    return null;
  }

  // --- configured? ---------------------------------------------------

  Component.onCompleted: tokenProbe.running = true;

  Process {
    id: tokenProbe;
    command: ["sh", "-c", 'test -s "$1" && echo yes || echo no', "sh", Config.lightsDevicesFile];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        root.configured = (t || "").trim() === "yes";
        if (root.configured) root.poll();
      }
    }
  }

  // --- poll ------------------------------------------------------------

  function poll() {
    if (!root.configured || pollProc.running) return;
    root.loading = true;
    pollProc.command = ["lights-ctl", "status", "--file", Config.lightsDevicesFile];
    pollProc.running = true;
  }

  Process {
    id: pollProc;
    stdout: StdioCollector { id: pollOut }
    onExited: (code, status) => {
      root.loading = false;
      if (code !== 0) { root.error = "lights-ctl status failed."; return; }
      // A poll started before the user grabbed a slider can still land
      // mid-interaction; applying it would yank the handle off the value
      // being dragged / waiting to be written. Drop it — `_busy` clearing
      // fires a fresh reconcile poll.
      if (root._busy) return;

      var raw = (typeof pollOut.text === "function" ? pollOut.text() : pollOut.text) || "";
      try {
        var data = JSON.parse(raw);
        var incoming = (data.devices || []).map((d) => ({
          id: d.id,
          name: d.name || d.id,
          caps: d.caps || ["power", "brightness", "color"],
          reachable: !!d.reachable,
          on: !!d.on,
          brightness: d.brightness !== undefined ? d.brightness / 100 : 0,
          temperature: d.temperature !== undefined ? d.temperature / 100 : 0,
          rgb: d.rgb || [255, 255, 255],
        }));

        var nextIds = JSON.stringify(incoming.map((d) => d.id));
        if (nextIds !== root._lastIds) {
          root._lastIds = nextIds;
          root.revision++;
        }
        root.devices = incoming;
        root.statusRevision++;
        root.error = "";
      } catch (e) {
        root.error = "Bad response from lights-ctl.";
      }
    }
  }

  // 25s continuous background poll drives `reachable` (and thus the drawer
  // tile) even when the app isn't open; 5s while it is, for responsive live
  // status (e.g. a bulb toggled by voice through Google Home). Paused while
  // `_busy` (dragging, or a write pending/in-flight) so a landing poll can't
  // fight an optimistic value; `_busy` going false triggers a reconcile poll.
  Timer {
    interval: root.appActive ? 5000 : 25000;
    running: root.configured && !root._busy;
    repeat: true; triggeredOnStart: true;
    onTriggered: root.poll();
  }
  // triggeredOnStart only fires when the timer starts, not on every interval
  // change — so opening the app needs its own nudge to actually feel snappy.
  onAppActiveChanged: if (appActive) root.poll();

  // --- writes ------------------------------------------------------------

  // True while the user is actively steering a light: dragging, a settle
  // timer counting down, or a coalesced write draining. Gates the poll (see
  // above) so nothing overwrites an optimistic value before the real bulb
  // has caught up.
  readonly property bool _busy: root.dragActive || sliderSettle.running
    || powerSettle.running || root._flushing;
  property bool _flushing: false;

  // Local optimistic update, applied immediately so the UI never waits on the
  // network round-trip; the settle timers below send the real command once
  // the user stops fiddling, and a reconcile poll follows.
  function setPower(id, on) {
    var d = root._findDevice(id);
    if (d) d.on = on;
    root.statusRevision++;
    root._markDirty(id, "power", on);
    powerSettle.restart();   // a toggle shouldn't wait out the slider settle
  }
  function setBrightness(id, fraction) {
    var pct = Math.round(Math.max(0, Math.min(1, fraction)) * 100);
    var d = root._findDevice(id);
    if (d) d.brightness = pct / 100;
    root.statusRevision++;
    root._markDirty(id, "brightness", pct);
    sliderSettle.restart();
  }
  // fraction: 0 = warmest, 1 = coolest (white-temperature bulbs only).
  function setTemperature(id, fraction) {
    var pct = Math.round(Math.max(0, Math.min(1, fraction)) * 100);
    var d = root._findDevice(id);
    if (d) d.temperature = pct / 100;
    root.statusRevision++;
    root._markDirty(id, "temperature", pct);
    sliderSettle.restart();
  }
  function setColor(id, h, s, v) {
    var rgb = root.hsvToRgb(h, s, v);
    var d = root._findDevice(id);
    if (d) d.rgb = rgb;
    root.statusRevision++;
    root._markDirty(id, "rgb", rgb);
    sliderSettle.restart();
  }

  property var _dirty: ({});   // id -> {power?, brightness?, temperature?, rgb?}
  property var _cmdQueue: [];

  function _markDirty(id, field, value) {
    if (!root._dirty[id]) root._dirty[id] = {};
    root._dirty[id][field] = value;
  }

  // A slider/wheel drag is followed live by the optimistic UI; the real bulb
  // is only told once the handle has been still for a second — one write per
  // gesture instead of a stream of them at a laggy Tuya bulb. A power toggle
  // gets a much shorter settle (just enough to fold a double-tap). Both drain
  // through the same single-flight queue, same shape as ChecklistService's
  // patchDebounce/_drain/patchProc.
  Timer { id: sliderSettle; interval: 1000; onTriggered: root._flush(); }
  Timer { id: powerSettle; interval: 150; onTriggered: root._flush(); }

  function _flush() {
    for (var id in root._dirty) {
      var patch = root._dirty[id];
      if ("power" in patch) root._cmdQueue.push(["power", id, patch.power ? "on" : "off"]);
      if ("brightness" in patch) root._cmdQueue.push(["brightness", id, String(patch.brightness)]);
      if ("temperature" in patch) root._cmdQueue.push(["temperature", id, String(patch.temperature)]);
      if ("rgb" in patch) root._cmdQueue.push(["color", id, String(patch.rgb[0]), String(patch.rgb[1]), String(patch.rgb[2])]);
    }
    root._dirty = ({});
    root._flushing = true;
    root._drain();
  }

  function _drain() {
    if (writeProc.running) return;
    if (root._cmdQueue.length === 0) {
      if (root._flushing) { root._flushing = false; root.poll(); }
      return;
    }
    var cmd = root._cmdQueue.shift();
    writeProc.command = ["lights-ctl"].concat(cmd, ["--file", Config.lightsDevicesFile]);
    writeProc.running = true;
  }

  Process {
    id: writeProc;
    onExited: (code) => {
      if (code !== 0) root.error = "Couldn't reach a light.";
      root._drain();
    }
  }

  // --- color helpers -------------------------------------------------

  // h: 0-360, s/v: 0-1 -> [r,g,b] 0-255.
  function hsvToRgb(h, s, v) {
    var c = v * s;
    var x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    var m = v - c;
    var rp = 0, gp = 0, bp = 0;
    if (h < 60)       { rp = c; gp = x; bp = 0; }
    else if (h < 120) { rp = x; gp = c; bp = 0; }
    else if (h < 180) { rp = 0; gp = c; bp = x; }
    else if (h < 240) { rp = 0; gp = x; bp = c; }
    else if (h < 300) { rp = x; gp = 0; bp = c; }
    else              { rp = c; gp = 0; bp = x; }
    return [Math.round((rp + m) * 255), Math.round((gp + m) * 255), Math.round((bp + m) * 255)];
  }

  // [r,g,b] 0-255 -> {h: 0-360, s: 0-1, v: 0-1}.
  function rgbToHsv(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b);
    var d = max - min;
    var h = 0;
    if (d !== 0) {
      if (max === r) h = 60 * (((g - b) / d) % 6);
      else if (max === g) h = 60 * ((b - r) / d + 2);
      else h = 60 * ((r - g) / d + 4);
    }
    if (h < 0) h += 360;
    return { h: h, s: max === 0 ? 0 : d / max, v: max };
  }
}
