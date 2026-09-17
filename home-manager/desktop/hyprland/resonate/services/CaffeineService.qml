pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// "Keep awake" toggle. hypridle honours logind idle inhibitors (no
// ignore_dbus_inhibit in its config), so holding a `systemd-inhibit
// --what=idle` process open is enough to suspend the dim/lock/dpms timers
// for as long as it runs.
Singleton {
  id: root;

  property bool active: false;

  function toggle() { root.active = !root.active; }

  Process {
    id: inhibitor;
    command: ["systemd-inhibit", "--what=idle:sleep", "--who=resonate",
              "--why=Caffeine", "--mode=block", "sleep", "infinity"];
    running: root.active;
  }
}
