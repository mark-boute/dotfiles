//@ pragma UseQApplication

import Quickshell
import QtQuick

import qs

ShellRoot {
  id: root;

  Loader {
    active: true;
    sourceComponent: Screen {}
  }
}
