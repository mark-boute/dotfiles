import QtQuick
import Quickshell.Widgets

import qs

// A single system tray icon, shared between PowerStatus's collapsed and
// expanded rows. Left click focuses the app's actual window via
// `owner.focusApp` (switching to its workspace as part of that) rather
// than the SNI Activate() method, whose behavior is entirely up to the
// app; right click opens its context menu via `owner.activeMenuItem` if
// it has one, else sends the SNI secondary-activate.
Item {
  id: trayIcon;
  // Not named modelData: this is instantiated inside a Repeater, and
  // `modelData: modelData` would have this property's own declaration
  // shadow the Repeater's injected context property of the same name,
  // self-referencing instead of picking up the actual tray item.
  required property var trayItem;
  required property var owner; // the PowerStatus `power` instance
  readonly property bool isInteractive: true;

  implicitWidth: Theme.iconSize;
  implicitHeight: Theme.iconSize;
  // A plain Item doesn't auto-bind width/height to implicitWidth/Height —
  // see PowerStatus's chevron for why that matters for tap exclusion.
  width: implicitWidth;
  height: implicitHeight;

  IconImage {
    anchors {
      fill: this.parent;
      centerIn: this.parent;
    }

    source: {
      if (modelData.icon.includes("?path=")) {
        const [name, path] = modelData.icon.split("?path=");
        return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
      }
      return modelData.icon;
    }
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton;
    onTapped: trayIcon.owner.focusApp(trayIcon.trayItem);
  }

  TapHandler {
    acceptedButtons: Qt.RightButton;
    onTapped: {
      trayIcon.owner.markControlActivated();
      if (trayIcon.trayItem.hasMenu) trayIcon.owner.openMenuFor(trayIcon.trayItem);
      else trayIcon.trayItem.secondaryActivate();
    }
  }
}
