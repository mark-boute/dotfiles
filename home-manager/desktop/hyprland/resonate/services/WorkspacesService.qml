pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Reorganising workspaces from the panel (WorkspacesPanel.qml).
//
// Hyprland has no "reorder" — workspaces always render sorted by id — so a
// drag onto another tile is a *swap*: workspace A and B trade id (and thus
// their spot in the bar), done with `hl.dsp.workspace.change_id`. Nothing
// moves between workspaces, so every window's tiled/floating layout, split
// ratios and focus history are preserved exactly; only the number changes.
// The swap goes A→tmp, B→A, tmp→B through a scratch id above every real one.
//
// change_id emits no event Quickshell listens for, so the model is refreshed
// by hand afterwards. If the dragged workspace was the focused one, focus is
// sent after it to its new number so the view follows the windows.
//
// Dispatches go through `hyprctl dispatch 'hl.dsp.*'` — this Hyprland runs a
// Lua config plugin that parses even the raw-socket dispatch string as Lua
// (see hypr/keybinds.lua), so neither `hyprctl dispatch <bareword>` nor
// Quickshell's Hyprland.dispatch() work; the `hl.dsp.*` call form does.
Singleton {
  id: root;

  // Bumped after a reorder settles — the panel keys its tile list off this so
  // the previews rebuild (change_id mutates ids in place, which the model
  // doesn't always surface as a list change).
  property int reorderTick: 0;

  property var _queue: [];
  property bool _busy: false;

  Process {
    id: proc;
    onExited: root._pump();
  }

  // change_id has usually landed by the time `hyprctl` returns, but not
  // always — refresh again a beat later so the panel/bar can't be left stale.
  Timer {
    id: settle;
    interval: 250;
    repeat: true;
    property int ticks: 0;
    onTriggered: {
      Hyprland.refreshWorkspaces();
      Hyprland.refreshMonitors();
      Hyprland.refreshToplevels();
      root.reorderTick++;
      if (++ticks >= 3) { stop(); ticks = 0; }
    }
  }

  function _pump() {
    if (root._queue.length === 0) {
      root._busy = false;
      Hyprland.refreshWorkspaces();
      Hyprland.refreshMonitors();
      Hyprland.refreshToplevels();
      root.reorderTick++;
      settle.ticks = 0;
      settle.restart();
      return;
    }
    root._busy = true;
    proc.command = ["hyprctl", "dispatch", root._queue.shift()];
    proc.running = true;
  }

  function _run(cmds) {
    root._queue = root._queue.concat(cmds);
    if (!root._busy) root._pump();
  }

  function _maxId() {
    var m = 0;
    var vals = Hyprland.workspaces.values;
    for (var i = 0; i < vals.length; i++)
      if (vals[i] && vals[i].id > m) m = vals[i].id;
    return m;
  }

  function _changeId(from, to) {
    return "hl.dsp.workspace.change_id({ workspace = " + from + ", id = " + to + " })";
  }

  // Swap workspaces `a` and `b` (numeric ids) — they exchange id, so what was
  // on A now carries B's number and vice versa. Layout untouched. If A was the
  // focused workspace, the view follows it to B.
  function swapContents(a, b) {
    if (!a || !b || a === b) return;
    var tmp = Math.max(a, b, _maxId()) + 1;
    var followFocus = Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === a;
    var cmds = [_changeId(a, tmp), _changeId(b, a), _changeId(tmp, b)];
    if (followFocus) cmds.push("hl.dsp.focus({ workspace = " + b + " })");
    _run(cmds);
  }

  // Move a whole workspace to another monitor by name.
  function moveToMonitor(id, monitorName) {
    if (!id || !monitorName) return;
    _run(["hl.dsp.workspace.move({ workspace = " + id + ", monitor = \"" + monitorName + "\" })"]);
  }
}
