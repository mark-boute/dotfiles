pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// dGPU (NVIDIA, PCI 0000:01:00.0) runtime-PM state, for the power panel's
// indicator and slider. Reads `power/runtime_status` — NOT `power_state`:
// reading power_state on this driver resumes the card (~2s of D0), which at a
// poll interval would keep it out of D3cold entirely (several watts).
//
// `power/control` is the kernel's runtime-PM switch: "auto" lets the card
// sleep when idle, "on" keeps it awake. It's writable only via the gpucontrol
// group (udev rule in hosts/legion/configuration.nix); `controllable` gates
// the slider on that. Not persisted — every boot starts on auto.
Singleton {
  id: root;

  readonly property string base: "/sys/bus/pci/devices/0000:01:00.0/power";

  property string status: "";               // active / suspended / suspending / resuming
  readonly property bool awake: status !== "" && status !== "suspended";
  property string control: "";              // auto / on
  readonly property bool forcedOn: control === "on";
  property bool controllable: false;

  function setForcedOn(on) {
    if (!root.controllable)
      return;
    root.control = on ? "on" : "auto";
    writeProc.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", root.control, root.base + "/control"];
    writeProc.running = true;
  }

  Process {
    id: writeProc;
    onExited: settleTimer.restart();
  }
  // The card takes ~1s to resume or suspend after a switch.
  Timer { id: settleTimer; interval: 1500; onTriggered: proc.running = true; }

  Process {
    id: proc;
    command: ["sh", "-c",
      "cat \"$1/runtime_status\" \"$1/control\"; [ -w \"$1/control\" ] && echo w || echo r",
      "sh", root.base];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        var lines = (t || "").trim().split("\n");
        root.status = (lines[0] || "").trim();
        root.control = (lines[1] || "").trim();
        root.controllable = (lines[2] || "").trim() === "w";
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
