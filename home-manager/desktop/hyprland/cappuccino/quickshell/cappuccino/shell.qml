//@ pragma UseQApplication

import Quickshell
import QtQuick
import Quickshell.Hyprland

import qs
import qs.modules as Modules
import qs.services as Services

ShellRoot {
  id: root;

  Loader {
    id: barLoader;
    active: true;
    sourceComponent: Screen {}
  }

  Modules.SessionLock { id: lock; }
  Services.GlobalShortcuts { onPressed: lock.locked = true; }
}