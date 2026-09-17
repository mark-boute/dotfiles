pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// dGPU (NVIDIA, PCI 0000:01:00.0) runtime-PM state, for the power panel's
// indicator. Reads `power/runtime_status` — NOT `power_state`: reading
// power_state on this driver resumes the card (~2s of D0), which at a poll
// interval would keep it out of D3cold entirely (several watts).
Singleton {
  id: root;

  property string status: "";               // active / suspended / suspending / resuming
  readonly property bool awake: status !== "" && status !== "suspended";

  Process {
    id: proc;
    command: ["cat", "/sys/bus/pci/devices/0000:01:00.0/power/runtime_status"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        root.status = (t || "").trim();
      }
    }
  }

  Timer {
    interval: 15000;
    repeat: true;
    running: true;
    triggeredOnStart: true;
    onTriggered: proc.running = true;
  }
}
