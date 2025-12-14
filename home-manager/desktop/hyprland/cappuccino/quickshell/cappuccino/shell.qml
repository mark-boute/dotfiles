//@ pragma UseQApplication

import Quickshell
import QtQuick
import Quickshell.Hyprland

import qs.modules as M

ShellRoot {
  id: root;

  Loader {
    id: barLoader;
    active: true;
    sourceComponent: M.Bar{}
  }
}