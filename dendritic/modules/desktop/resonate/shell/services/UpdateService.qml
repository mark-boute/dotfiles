pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// System update for the system panel's update tile: runs
// scripts/system_update.sh (flake update → unprivileged build → switch via
// nixos-switch-to@.service, which polkit guards with a password prompt) and
// follows its "PHASE"/"COUNT"/"RESULT" lines. The last result survives
// restarts in $XDG_STATE_HOME/resonate/update.json.
Singleton {
  id: root;

  readonly property string stateDir:
    (Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state")) + "/resonate";
  readonly property string logPath: stateDir + "/update.log";

  readonly property bool running: proc.running;
  property string phase: "";     // inputs / build / fetch / auth
  property string detail: "";
  property int built: 0;
  property int total: 0;
  property int elapsed: 0;       // seconds, while running

  // last finished run: { status: updated|uptodate|failed, phase, message, changed[], finished }
  property var last: null;

  function start() {
    if (proc.running)
      return;
    root.phase = "inputs";
    root.detail = "";
    root.built = 0;
    root.total = 0;
    root.elapsed = 0;
    proc.running = true;
  }

  function openLog() {
    Quickshell.execDetached(["kitty", "--title", "System update", "less", "+G", root.logPath]);
  }

  Process {
    id: proc;
    command: ["bash", Quickshell.shellPath("scripts/system_update.sh")];
    stdout: SplitParser {
      onRead: (line) => {
        var parts = line.split(" ");
        if (parts[0] === "PHASE") {
          root.phase = parts[1] || "";
          root.detail = parts.slice(2).join(" ");
        } else if (parts[0] === "COUNT") {
          root.built = parseInt(parts[1]) || 0;
          root.total = parseInt(parts[2]) || 0;
        }
      }
    }
    onExited: {
      root.phase = "";
      result.reload();
    }
  }

  Timer {
    interval: 1000;
    repeat: true;
    running: proc.running;
    onTriggered: root.elapsed++;
  }

  FileView {
    id: result;
    path: root.stateDir + "/update.json";
    printErrors: false;
    onLoaded: {
      try { root.last = JSON.parse(result.text()); } catch (e) { root.last = null; }
    }
  }
}
