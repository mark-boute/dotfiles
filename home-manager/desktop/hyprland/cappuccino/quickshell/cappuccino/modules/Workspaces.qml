import Quickshell
import Quickshell.Hyprland
import QtQuick

import qs.shapes as Shapes
import qs.services as Services

/*
  A workspace indicator widget.
  The indicators each represent a workspace.

  > The active workspace on the current monitor is highlighted in orange.
  > The inactive workspaces on the current monitor are shown in light color.
  > The workspaces on other monitors are shown in grey.

   - Clicking on an indicator switches to that workspace.
   - The workspace number is shown on the indicator for workspaces on the current monitor.

  Required property:
    - screen: The ShellScreen this widget is associated with, 
              used to determine which workspaces are on this monitor.
*/

Shapes.MenuPill {
  required property ShellScreen screen;
  property HyprlandMonitor monitor: Hyprland.monitorFor(screen);
  id: workspacesWidget;
  width: Hyprland.workspaces ? Hyprland.workspaces.values.length * 25 + 15 : 0;

  Row {
    id: workspace;
    spacing: 5;
    anchors {
      left: parent.left;
      verticalCenter: parent.verticalCenter;
      leftMargin: 10;
    }
  
    Repeater {
      model: Hyprland.workspaces;
      Rectangle {

        required property HyprlandWorkspace modelData;
        property bool onCurrentMonitor: modelData.monitor === monitor;

        width: 20;
        height: width;
        radius: 100;

        color: {
          if (onCurrentMonitor) {
            modelData.active ? "#fe640b" : "#f4dbd6";
          } else {
            "#8087a2";
          }
        } 

        Text {
          text: onCurrentMonitor ? modelData.id : "";
          anchors.centerIn: parent;
          color: modelData.active ? "#cad3f5" : "#24273a";
          font.weight: modelData.active ? Font.ExtraBold : Font.Medium;
        }

        MouseArea {
          anchors.fill: parent;
          onClicked: modelData.activate();
        }
      }
    }
  }
}
