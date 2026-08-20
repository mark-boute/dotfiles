pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Bluetooth on/off via bluetoothctl — same shape as NetworkService, see
// there for why this polls continuously instead of once-on-open.
Singleton {
  id: root;

  property bool enabled: false;

  Process {
    id: statusProc;
    command: ["sh", "-c", "bluetoothctl show | awk '/Powered/ {print $2}'"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        root.enabled = (t || "").trim() === "yes";
      }
    }
  }

  Process {
    id: toggleProc;
    command: ["sh", "-c", "bluetoothctl power " + (root.enabled ? "off" : "on")];
    onExited: statusProc.running = true;
  }

  function toggle() {
    toggleProc.running = true;
  }

  Timer {
    interval: 2000;
    repeat: true;
    triggeredOnStart: true;
    running: true;
    onTriggered: statusProc.running = true;
  }
}
