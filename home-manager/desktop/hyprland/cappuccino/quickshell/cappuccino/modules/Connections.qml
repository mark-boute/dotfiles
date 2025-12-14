import Quickshell
import QtQuick

import qs
import qs.services as Services
import qs.shapes as Shapes
import qs.widgets as Widgets

Rectangle {
  id: connectionsModule;
  width: 30;
  height: Theme.barHeight;
  radius: Theme.barHeight / 2;
  color: Services.Network.connected ? Theme.current.green : Theme.current.red;

  Shapes.IconImage {
    anchors.centerIn: parent;
    source: Services.Network.connected ? "qrc:/icons/wifi-connected.svg" : "qrc:/icons/wifi-disconnected.svg";
    width: 16;
    height: 16;
  }

  Text {
    text: "Hello";
  }

  MouseArea {
    anchors.fill: parent;
    onClicked: Services.Network.showConnectionDetails();
  }
}