import Quickshell
import QtQuick

import qs.shapes as Shapes
import qs.services as Services

Shapes.MenuPill {
  id: clockWidget;
  implicitWidth: clockText.implicitWidth + 20;

  Text {
    id: clockText;
    text: mouse.hovered ? Services.SystemClock.datetime : Services.SystemClock.time;
    anchors.centerIn: parent;
    color: "#f4dbd6";
    font.weight: Font.Medium;
  }

  // https://doc.qt.io/qt-6/qtquick-statesanimations-animations.html

  HoverHandler {
    id: mouse;
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad;
  }
}

