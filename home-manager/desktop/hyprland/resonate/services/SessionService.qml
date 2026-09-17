pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Power off / restart / log out, with a fullscreen confirm step (see
// modules/SessionOverlay.qml). Triggered by the quickshell:Session* globals
// bound in hypr/keybinds.lua. Nothing is closed until confirm() runs — the
// old hyprshutdown path is gone.
Singleton {
  id: root;

  // "" | "poweroff" | "reboot" | "logout"
  property string pending: "";

  readonly property var _defs: ({
    "poweroff": { title: "Power off", verb: "Power off", cmd: "systemctl poweroff",             danger: true,  glyph: 0xf0425 },
    "reboot":   { title: "Restart",   verb: "Restart",   cmd: "systemctl reboot",               danger: false, glyph: 0xf0709 },
    "logout":   { title: "Log out",   verb: "Log out",   cmd: "hyprctl dispatch 'hl.dsp.exit()'", danger: false, glyph: 0xf0343 },
  })
  readonly property var def: root._defs[root.pending] || null;

  // Windows whose title carries an unsaved-changes marker: [{ title, appClass }].
  property var dirty: [];

  function request(mode) {
    if (!root._defs[mode])
      return;
    root.dirty = [];
    scanProc.running = true;
    root.pending = mode;
  }

  function cancel() {
    root.pending = "";
  }

  function confirm() {
    if (!root.def)
      return;
    var c = root.def.cmd;
    root.pending = "";
    runProc.command = ["sh", "-c", c];
    runProc.running = true;
  }

  Process { id: runProc; }

  // No Wayland portal reports "unsaved" state, so this title-scans the
  // Hyprland client list for the markers editors tend to put in the window
  // title (VS Code's leading dot, a leading "*", "(modified)", gvim's " + ").
  // Best-effort: silent on apps that don't advertise it, and the list is
  // shown to the user to judge rather than acted on.
  Process {
    id: scanProc;
    command: ["hyprctl", "clients", "-j"];
    stdout: StdioCollector {
      onStreamFinished: {
        var txt = (typeof this.text === "function") ? this.text() : this.text;
        var seen = ({});
        var out = [];
        try {
          var arr = JSON.parse(txt || "[]");
          for (var i = 0; i < arr.length; i++) {
            var w = arr[i] || {};
            var t = (w.title || "").trim();
            if (!t || seen[t] || !root._looksDirty(t))
              continue;
            seen[t] = true;
            out.push({ title: t, appClass: w.class || "" });
          }
        } catch (e) {}
        root.dirty = out;
      }
    }
  }

  function _looksDirty(t) {
    return /●/.test(t)                                        // ● — VS Code / VSCodium / Cursor
      || /^\s*\*[^\s*]/.test(t)                                    // "*file …" — GIMP, Inkscape, Krita, gedit, Ardour
      || /\(modified\)|\[modified\]|\(unsaved\)|unsaved change/i.test(t)
      || /\s\+\s+-\s+g?vim/i.test(t);                              // gvim "name + - GVIM"
  }
}
