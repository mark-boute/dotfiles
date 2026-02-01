import Quickshell
import Quickshell.Hyprland
import QtQuick

import qs
import qs.shapes as Shapes

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
  implicitWidth: workspace.implicitWidth + Theme.defaultSpacing * 2;


  Row {
    id: workspace;
    spacing: Theme.defaultSpacing;
    anchors {
      left: parent.left;
      verticalCenter: parent.verticalCenter;
      leftMargin: Theme.defaultSpacing;
    }
  
    Repeater {
      model: Hyprland.workspaces;
      Rectangle {

        required property HyprlandWorkspace modelData;
        property bool onCurrentMonitor: modelData.monitor === monitor;

        height: Theme.barHeight - Theme.defaultSpacing * 2;
        width: this.height;
        radius: this.height / 2;

        color: {
          if (onCurrentMonitor) {
            modelData.active ? Theme.latte.peach : Theme.macchiato.rosewater;
          } else {
            Theme.macchiato.overlay1;
          }
        } 

        Text {
          text: onCurrentMonitor ? modelData.id : null;
          anchors.centerIn: parent;
          color: modelData.active ? Theme.latte.base : Theme.macchiato.base;
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
