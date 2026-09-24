import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs
import qs.services as Services
import qs.widgets as Widgets

// Session lock. Triggered by the `quickshell:Lock` global (SUPER+Escape and
// hypridle's lock_cmd). Auth via PAM (/etc/pam.d/swaylock — plain pam_unix,
// unprivileged).
//
// Locking grows the bar's clock pill into a full-screen sheet of frosted
// glass over a still of the screen (width first, height 40ms later), squares
// its corners off near the end, then fades to the lock screen while the bar
// clock flies into the big one. Unlocking plays it back: the lock screen
// fades to glass, the glass shrinks into the pill, then the lock releases.
Scope {
  id: scope;

  property bool locked: false;
  // Set on a successful login; the lock releases once the sheet has shrunk.
  property bool unlocking: false;

  GlobalShortcut {
    appid: "quickshell";
    name: "Lock";
    onPressed: { scope.unlocking = false; scope.locked = true; }
  }

  Timer {
    id: releaseTimer;
    interval: 820;
    onTriggered: { scope.locked = false; scope.unlocking = false; }
  }
  function release() {
    scope.unlocking = true;
    releaseTimer.restart();
  }

  // "Mark", from the passwd GECOS field, else the capitalised login.
  property string userName: {
    var u = Quickshell.env("USER") || "";
    return u.charAt(0).toUpperCase() + u.slice(1);
  }
  Process {
    running: true;
    command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"];
    stdout: StdioCollector {
      onStreamFinished: {
        var n = ((typeof this.text === "function") ? this.text() : this.text || "").trim();
        if (n) scope.userName = n.split(" ")[0];
      }
    }
  }

  WlSessionLock {
    id: lock;
    locked: scope.locked;

    WlSessionLockSurface {
      id: surface;
      color: CurrentTheme.background;

      Widgets.LockScreen {
        anchors.fill: parent;
        captureScreen: surface.screen;
        unlocking: scope.unlocking;
        userName: scope.userName;
        onAuthenticated: scope.release();
      }
    }
  }
}
