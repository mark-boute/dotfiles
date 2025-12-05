import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick.Layouts
import QtQuick

import qs.shapes as S

S.MenuPill {

  id: systemtrayWidget;

  property var items: SystemTray.items;

  implicitWidth: trayItem.implicitWidth + 20;

  Row {
    id: trayItem;
    spacing: 5;
    anchors {
      left: parent.left;
      verticalCenter: parent.verticalCenter;
      leftMargin: 10;
    }

    Repeater {
      model: items;

      Rectangle {

        required property var modelData;

        width: 20;
        height: this.width;
        radius: 100;

        color: "#24273a";

        IconImage {
          
          anchors.fill: this.parent;
          source: {
            if (modelData.icon.includes("?path=")) {
              const [name, path] = modelData.icon.split("?path=");
              return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
            }
            return modelData.icon;
          }
          anchors.centerIn: this.parent;
        }

        MouseArea {
          anchors.fill: this.parent;
          acceptedButtons: Qt.RightButton;
          onClicked: modelData.display(this.parent, 30, 50);
        }
      }
    }
  }
}