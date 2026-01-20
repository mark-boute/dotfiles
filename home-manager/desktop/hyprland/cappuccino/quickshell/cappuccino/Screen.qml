import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell

import qs
import qs.modules as Modules

Scope {

  Variants {
    model: Quickshell.screens;

    delegate: ColumnLayout {
      id: screen;
      required property var modelData;

      Modules.Bar { modelData: screen.modelData; }
      Modules.Background { modelData: screen.modelData; }
    }
  }
}
