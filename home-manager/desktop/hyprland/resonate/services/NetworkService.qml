pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wi-Fi on/off via nmcli — there's no dedicated Quickshell service for this,
// just a plain shell-out, polled continuously so any icon reading `enabled`
// stays live regardless of who else is also toggling it (e.g. PowerPanel's
// own tile). Shared here instead of duplicated per call site.
Singleton {
  id: root;

  property bool enabled: false;

  Process {
    id: statusProc;
    command: ["sh", "-c", "nmcli radio wifi"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        root.enabled = (t || "").trim() === "enabled";
      }
    }
  }

  Process {
    id: toggleProc;
    command: ["sh", "-c", "nmcli radio wifi " + (root.enabled ? "off" : "on")];
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
