pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import qs

// Auto-themes the shell by the sun. The Catppuccin flavour — and, through
// Theme.backgroundFor, the wallpaper — follows three coarse phases:
//
//   day      sun well up ................ frappe    (dark, day.jpg)
//   twilight the sun slowly lowering ..... macchiato (sunset.jpg)
//   night    sun below the horizon ....... mocha     (darkest, night.jpg)
//
// Same shape as TemperatureService's auto mode: a bool that any manual pick
// in ThemeApp switches off, a 60s tick, and SunService for the sun maths.
//
// autoMode and the flavour are persisted to
// ~/.config/resonate/theme.json so a restart doesn't reset the shell to the
// Theme.qml defaults; the stored flavour is only re-applied on load when
// autoMode is off (otherwise the sun decides).
Singleton {
  id: root;

  property bool autoMode: true;

  // How long before sunset counts as "the sun slowly lowering".
  readonly property real duskHours: 1.5;

  readonly property var phaseFlavor: ({
    "day": "frappe",
    "twilight": "macchiato",
    "night": "mocha",
  });

  // Set once the store has been read (or failed to). Until then _save() is a
  // no-op, so a change during load can't clobber the file with defaults.
  property bool _ready: false;

  // Called by ThemeApp's swatches instead of assigning Theme.flavor
  // directly, so a manual pick also drops auto mode (until toggled back on).
  function setFlavor(name, fromAuto) {
    if (!fromAuto)
      root.autoMode = false;
    Theme.flavor = name;
  }

  function applyAuto() {
    if (!root.autoMode)
      return;
    var f = root.phaseFlavor[SunService.sunPhase(root.duskHours)];
    if (f && f !== Theme.flavor)
      Theme.flavor = f;
  }

  // Rechecked every minute, same cadence as TemperatureService — the phase
  // boundaries are hard cuts so a coarser tick would just delay the switch.
  Timer {
    interval: 60000;
    repeat: true;
    running: true;
    triggeredOnStart: true;
    onTriggered: root.applyAuto();
  }

  onAutoModeChanged: {
    if (root.autoMode)
      root.applyAuto();
    root._save();
  }

  // --- persistence ---------------------------------------------------

  FileView {
    id: store;
    path: (Quickshell.env("HOME") || "") + "/.config/resonate/theme.json";
    printErrors: false;

    onLoaded: {
      root.autoMode = adapter.autoMode;
      if (!adapter.autoMode && adapter.flavor)
        Theme.flavor = adapter.flavor;
      root._ready = true;
      root.applyAuto();
      // Explicit, not left to onFlavorChanged below —
      // those only fire on an actual value change, so a persisted theme
      // that happens to match Theme.qml's compiled-in defaults would
      // otherwise never get the cursor applied at all.
      root._applyCursor();
    }
    onLoadFailed: {
      // No file yet (first run): keep the defaults, let auto mode place the
      // flavour, and write the file out now so it exists next time.
      root._ready = true;
      root.applyAuto();
      root._save();
      root._applyCursor();
    }

    JsonAdapter {
      id: adapter;
      property bool autoMode: true;
      property string flavor: "macchiato";
    }
  }

  function _save() {
    if (!root._ready)
      return;
    adapter.autoMode = root.autoMode;
    adapter.flavor = Theme.flavor; // consulted on load only when autoMode is off
    store.writeAdapter();
  }

  // --- live cursor theme -----------------------------------------------

  // Matches the system pointer cursor to whatever flavor/accent is actually
  // showing, immediately — `hyprctl setcursor` takes effect on already-open
  // clients with no relogin. Needs every catppuccin-cursors flavor×accent
  // theme installed (default.nix: catppuccin-cursors.all) since
  // home.pointerCursor itself only ever ships the one pair baked in at
  // build time, which this is specifically here to override.
  readonly property int cursorSize: 24;
  Process { id: cursorProc; }
  // setcursor alone leaves the image already on screen untouched until the
  // pointer's shape changes, so re-dispatch the pointer to its own position.
  function _applyCursor() {
    cursorProc.command = ["sh", "-c",
      'hyprctl setcursor "$1" "$2"; p=$(hyprctl cursorpos); ' +
      'hyprctl dispatch "hl.dsp.cursor.move({x=${p%%,*},y=${p##*, }})"',
      "sh",
      "catppuccin-" + Theme.flavor + "-" + Theme.cursorAccent + "-cursors",
      String(root.cursorSize)];
    cursorProc.running = true;
  }

  Connections {
    target: Theme;
    function onFlavorChanged() { root._save(); root._applyCursor(); }
  }

  Component.onCompleted: store.reload();
}
