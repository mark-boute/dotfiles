pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wi-Fi via nmcli. The radio on/off state (`enabled`) is polled continuously so
// any icon reading it stays live. The scan list is populated on demand —
// scan() when the SystemPanel's Wi-Fi dropdown opens, refresh() on a timer while
// it stays open.
Singleton {
  id: root;

  property bool enabled: false;

  // [{ ssid, signal (0-100), secure, active, saved }]
  property var networks: [];
  property bool scanning: false;
  property string activeSsid: "";

  // Connect-attempt feedback for the UI.
  property string busySsid: "";
  property string errorSsid: "";
  property string errorText: "";

  property var _savedNames: ({});
  property bool _pendingRescan: false;
  property string _connectSsid: "";

  function _splitTerse(line) {
    // nmcli -t escapes ':' as '\:' and '\' as '\\'.
    var out = [], cur = "";
    for (var i = 0; i < line.length; i++) {
      var c = line[i];
      if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
      else if (c === ":") { out.push(cur); cur = ""; }
      else cur += c;
    }
    out.push(cur);
    return out;
  }

  function _find(ssid) {
    for (var i = 0; i < root.networks.length; i++)
      if (root.networks[i].ssid === ssid) return root.networks[i];
    return null;
  }

  // --- radio on/off ------------------------------------------------------

  Process {
    id: radioProc;
    command: ["nmcli", "radio", "wifi"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        root.enabled = (t || "").trim() === "enabled";
      }
    }
  }

  Process {
    id: toggleProc;
    onExited: radioProc.running = true;
  }
  function toggle() {
    toggleProc.command = ["nmcli", "radio", "wifi", root.enabled ? "off" : "on"];
    toggleProc.running = true;
  }

  // Wi-Fi radio on/off for the tile — a toggle indicator doesn't need 3s
  // freshness (toggle() refreshes right after acting). One nmcli spawn per
  // 12s instead of per 3s.
  Timer {
    interval: 12000; repeat: true; running: true; triggeredOnStart: true;
    onTriggered: radioProc.running = true;
  }

  // --- scan / list -----------------------------------------------------

  function scan() {
    if (!root.enabled) { root.networks = []; return; }
    root.scanning = true;
    root._pendingRescan = true;
    savedProc.running = true;
  }

  function refresh() {
    if (!root.enabled || root.scanning) return;
    root._pendingRescan = false;
    savedProc.running = true;
  }

  Process {
    id: savedProc;
    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        var names = {};
        (t || "").trim().split("\n").forEach((line) => {
          if (!line) return;
          var f = root._splitTerse(line);
          if ((f[1] || "").indexOf("wireless") !== -1) names[f[0]] = true;
        });
        root._savedNames = names;
      }
    }
    onExited: {
      if (root._pendingRescan) { root._pendingRescan = false; rescanProc.running = true; }
      else listProc.running = true;
    }
  }

  Process {
    id: rescanProc;
    command: ["nmcli", "device", "wifi", "rescan"];
    onExited: listDelay.restart(); // fails harmlessly if called too soon
  }
  Timer { id: listDelay; interval: 1800; onTriggered: listProc.running = true; }

  Process {
    id: listProc;
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        var by = {};
        var active = "";
        (t || "").trim().split("\n").forEach((line) => {
          if (!line) return;
          var f = root._splitTerse(line);
          var inUse = (f[0] || "").trim() === "*";
          var ssid = (f[1] || "").trim();
          if (!ssid) return;
          var sig = parseInt(f[2]) || 0;
          var sec = (f[3] || "").trim();
          var secure = sec !== "" && sec !== "--";
          if (inUse) active = ssid;
          var prev = by[ssid];
          if (!prev || sig > prev.signal) {
            by[ssid] = { ssid: ssid, signal: sig, secure: secure,
                         active: inUse || (prev && prev.active),
                         saved: !!root._savedNames[ssid] };
          } else if (inUse) {
            prev.active = true;
          }
        });
        var list = Object.keys(by).map((k) => by[k]);
        list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
        root.networks = list;
        root.activeSsid = active;
        root.scanning = false;
      }
    }
    onExited: (code) => { if (code !== 0) root.scanning = false; }
  }

  // --- connect / disconnect / forget ----------------------------------

  function connect(ssid, password) {
    root.errorSsid = "";
    root.errorText = "";
    root.busySsid = ssid;
    root._connectSsid = ssid;
    var net = _find(ssid);
    if (net && net.saved)
      connectProc.command = ["nmcli", "connection", "up", "id", ssid];
    else if (password && password.length > 0)
      connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
    else
      connectProc.command = ["nmcli", "device", "wifi", "connect", ssid];
    connectProc.running = true;
  }

  function disconnect() {
    if (!root.activeSsid) return;
    connectProc.command = ["nmcli", "connection", "down", "id", root.activeSsid];
    root._connectSsid = "";
    connectProc.running = true;
  }

  function forget(ssid) {
    forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
    forgetProc.running = true;
  }

  Process {
    id: connectProc;
    stderr: StdioCollector { id: connectErr }
    onExited: (code) => {
      root.busySsid = "";
      if (code !== 0 && root._connectSsid) {
        var e = (typeof connectErr.text === "function" ? connectErr.text() : connectErr.text) || "";
        root.errorSsid = root._connectSsid;
        root.errorText = (e.trim().split("\n").pop() || "Couldn't connect.").replace(/^Error:\s*/, "");
      } else {
        root.errorSsid = "";
        root.errorText = "";
      }
      root._connectSsid = "";
      refreshTimer.restart();
    }
  }

  Process {
    id: forgetProc;
    onExited: refreshTimer.restart();
  }

  Timer { id: refreshTimer; interval: 600; onTriggered: root.refresh(); }
}
