import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick.Layouts
import QtQuick

import qs.shapes as S

S.MenuPill {

  id: systemtrayWidget;

  width: SystemTray.items ? SystemTray.items.values.length * 25 + 15 : 0;

  // Component.onCompleted: {
  //   SystemTray.items.valuesChanged.connect(
  //     function() {
  //       systemtrayWidget.width = SystemTray.items ? SystemTray.items.values.length * 25 + 15 : 0;
  //     }
  //   );
  // }

  Row {
    id: trayItem;
    spacing: 5;
    anchors {
      left: parent.left;
      verticalCenter: parent.verticalCenter;
      leftMargin: 10;
    }

    Repeater {
      model: SystemTray.items;

      Rectangle {

        required property var modelData;

        width: 20;
        height: width;
        radius: 100;

        color: "#24273a";

        IconImage {
          
          anchors.fill: parent;
          source: {
            if (modelData.icon.includes("?path=")) {
              const [name, path] = modelData.icon.split("?path=");
              return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
            }
            return modelData.icon;
          }
          anchors.centerIn: parent;
        }

        MouseArea {
          anchors.fill: parent;
          acceptedButtons: Qt.RightButton;
          onClicked: modelData.display(parent, 30, 50);
        }
      }
    }
  }
}