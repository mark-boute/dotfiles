pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Bluetooth via bluetoothctl. Power state (`enabled`) is polled continuously.
//
// Discovery streams `bluetoothctl scan on`'s own output line by line so device
// names appear as bluez resolves them — `bluetoothctl devices` on its own just
// reports the MAC until then. Paired/connected/trusted flags come from a
// separate query. Nameless, unpaired devices are hidden as noise.
//
// connect() trusts + pairs + connects in one go; bluetoothctl 5.65+ registers
// its own agent per call so "just works" devices pair headlessly. PIN devices
// just report an error.
Singleton {
  id: root;

  property bool enabled: false;

  // [{ mac, name, named, paired, connected, trusted }]
  property var devices: [];
  property bool scanning: false;

  property string busyMac: "";
  property string errorMac: "";
  property string errorText: "";
  property string _opMac: "";

  property var _names: ({});    // mac -> name, accumulated from the scan stream
  property var _status: ({});   // mac -> { paired, connected, trusted, name }

  function _clean(s) {
    return (s || "").replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/[\r\x00-\x08\x0e-\x1f]/g, "");
  }
  function _isMacName(name, mac) {
    return name.replace(/[-:]/g, "").toUpperCase() === mac.replace(/[-:]/g, "").toUpperCase();
  }

  // --- power on/off ----------------------------------------------------

  Process {
    id: statusProc;
    command: ["sh", "-c", "bluetoothctl show 2>/dev/null | awk '/Powered/ {print $2; exit}'"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        root.enabled = (t || "").trim() === "yes";
      }
    }
  }

  Process {
    id: toggleProc;
    onExited: statusProc.running = true;
  }
  function toggle() {
    toggleProc.command = root.enabled
      ? ["sh", "-c", "bluetoothctl power off"]
      : ["sh", "-c", "rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on"];
    toggleProc.running = true;
  }

  // Just tracks the on/off state for the tile — spawning bluetoothctl (a
  // full bluez dbus session each time) every couple of seconds forever, while
  // BT is usually rfkilled at boot anyway, isn't worth it. 8s is plenty; the
  // toggle() path refreshes immediately on its own.
  Timer {
    interval: 8000; repeat: true; triggeredOnStart: true; running: true;
    onTriggered: statusProc.running = true;
  }

  // --- discovery ------------------------------------------------------

  readonly property int scanSeconds: 20;

  function scan() {
    if (!root.enabled) { root.devices = []; return; }
    root.scanning = true;
    root._names = ({});
    scanProc.running = true;
    statusListProc.running = true;
    scanStop.restart();
  }

  function refresh() {
    if (root.enabled) statusListProc.running = true;
  }

  Process {
    id: scanProc;
    command: ["sh", "-c",
      "exec stdbuf -oL bluetoothctl --timeout " + root.scanSeconds + " scan on 2>/dev/null"];
    stdout: SplitParser {
      onRead: (line) => root._parseScanLine(line);
    }
    onExited: { root.scanning = false; statusListProc.running = true; }
  }

  Timer {
    id: scanStop;
    interval: root.scanSeconds * 1000 + 1500;
    onTriggered: { root.scanning = false; statusListProc.running = true; }
  }

  function _parseScanLine(raw) {
    var line = root._clean(raw).trim();
    var m = line.match(/\bDevice\s+([0-9A-Fa-f:]{17})\s+(.*)$/);
    if (!m) return;
    var mac = m[1].toUpperCase();
    var rest = m[2].trim();
    var name = "";
    var kv = rest.match(/^(Name|Alias):\s*(.+)$/);
    if (kv) name = kv[2].trim();
    else if (rest.length > 0 && rest.indexOf(":") === -1) name = rest;
    else return; // RSSI / UUIDs / ManufacturerData / …
    if (!name || root._isMacName(name, mac)) return;
    var n = root._names;
    if (n[mac] === name) return;
    n[mac] = name;
    root._names = n;
    _rebuild();
  }

  Process {
    id: statusListProc;
    command: ["sh", "-c",
      "paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}'); " +
      "conn=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); " +
      "trust=$(bluetoothctl devices Trusted 2>/dev/null | awk '{print $2}'); " +
      "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do " +
      "  [ -z \"$mac\" ] && continue; p=n; c=n; t=n; bat=; " +
      "  printf '%s\\n' \"$paired\" | grep -qx \"$mac\" && p=y; " +
      "  printf '%s\\n' \"$conn\"   | grep -qx \"$mac\" && c=y; " +
      "  printf '%s\\n' \"$trust\"  | grep -qx \"$mac\" && t=y; " +
      "  [ \"$c\" = y ] && bat=$(bluetoothctl info \"$mac\" 2>/dev/null | sed -n 's/.*Battery Percentage:[^(]*(\\([0-9]*\\)).*/\\1/p'); " +
      "  printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$p\" \"$c\" \"$t\" \"$bat\" \"$name\"; done"];
    stdout: StdioCollector {
      onStreamFinished: {
        var tx = (typeof this.text === "function") ? this.text() : this.text;
        var s = {};
        root._clean(tx).trim().split("\n").forEach((line) => {
          if (!line) return;
          var f = line.split("\t");
          var mac = (f[0] || "").trim().toUpperCase();
          if (!mac) return;
          s[mac] = { paired: f[1] === "y", connected: f[2] === "y", trusted: f[3] === "y",
                     battery: (f[4] || "").trim() !== "" ? parseInt(f[4]) : -1,
                     name: (f[5] || "").trim() };
        });
        root._status = s;
        _rebuild();
      }
    }
  }

  function _rebuild() {
    var macs = {};
    for (var k in root._names) macs[k] = true;
    for (var j in root._status) macs[j] = true;

    var list = [];
    for (var mac in macs) {
      var st = root._status[mac] || {};
      var scanName = root._names[mac] || "";
      var storedName = (st.name && !root._isMacName(st.name, mac)) ? st.name : "";
      var name = scanName || storedName;
      var named = name !== "";
      if (!named && !st.paired) continue; // drop nameless, unpaired noise
      list.push({
        mac: mac,
        name: named ? name : mac,
        named: named,
        paired: !!st.paired,
        connected: !!st.connected,
        trusted: !!st.trusted,
        battery: (st.battery === undefined) ? -1 : st.battery,
      });
    }
    list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                        || a.name.localeCompare(b.name));
    root.devices = list;
  }

  // --- connect / disconnect / forget ---------------------------------

  function connect(mac) {
    root.busyMac = mac;
    root._opMac = mac;
    root.errorMac = "";
    root.errorText = "";
    opProc.command = ["sh", "-c",
      "m=\"$1\"; bluetoothctl trust \"$m\" >/dev/null 2>&1; " +
      "bluetoothctl pair \"$m\" >/dev/null 2>&1; " +
      "bluetoothctl connect \"$m\" 2>&1", "sh", mac];
    opProc.running = true;
  }

  function disconnect(mac) {
    root.busyMac = mac;
    root._opMac = "";
    opProc.command = ["sh", "-c", "bluetoothctl disconnect \"$1\" 2>&1", "sh", mac];
    opProc.running = true;
  }

  function forget(mac) {
    root.busyMac = mac;
    root._opMac = "";
    opProc.command = ["sh", "-c", "bluetoothctl remove \"$1\" 2>&1", "sh", mac];
    opProc.running = true;
  }

  Process {
    id: opProc;
    stdout: StdioCollector { id: opOut }
    onExited: (code) => {
      root.busyMac = "";
      if (code !== 0 && root._opMac) {
        var o = root._clean((typeof opOut.text === "function" ? opOut.text() : opOut.text) || "");
        var fail = o.trim().split("\n").filter(l => /fail|error|not available|br-connection/i.test(l)).pop();
        root.errorMac = root._opMac;
        root.errorText = (fail || "Couldn't connect.").replace(/.*:\s*/, "");
      }
      root._opMac = "";
      opRefresh.restart();
    }
  }
  Timer { id: opRefresh; interval: 700; onTriggered: root.refresh(); }
}
