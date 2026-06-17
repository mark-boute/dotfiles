import Quickshell
import QtQuick

import qs
import qs.shapes as Shapes
import qs.services as Services

Shapes.MenuPill {
  id: clockWidget;
  implicitWidth: clockText.implicitWidth + Theme.defaultMargin * 2;

  Text {
    id: clockText;
    text: mouse.hovered ? Services.SystemClock.datetime : Services.SystemClock.time;
    anchors.centerIn: parent;
    color: Theme.current.rosewater;
    font.pixelSize: 15;
    font.weight: Font.Medium;
  }

  HoverHandler {
    id: mouse;
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad;
  }
}

