import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell

import qs
import qs.widgets as Widgets

Scope{

  Variants {
    model: Quickshell.screens;

    delegate: Component {
      PanelWindow {
        id: panel;
        required property var modelData;
        screen: modelData;

        anchors { top: true; left: true; right: true; }
        color: Theme.barColor;
        implicitHeight: Theme.barHeight + Theme.barVerticalMargin * 2;

        // Modules
        Workspaces {
          screen: modelData;
          anchors {
            left: parent.left;
            leftMargin: Theme.barHorizontalMargin;
            verticalCenter: parent.verticalCenter;
          }
        }

        Widgets.Clock {
          id: clockWidget;
          anchors.centerIn: parent;
        }

        // Wrapper for right aligned widgets
        RowLayout {

          id: rightWidgetRow;
          spacing: Theme.defaultSpacing;

          width: Math.min(
            this.implicitWidth, 
            panel.width / 3
          ); 

          anchors {
            right: parent.right;
            rightMargin: Theme.barHorizontalMargin;
            verticalCenter: parent.verticalCenter;
          }
          
          Widgets.Systemtray { trayPopupAnchor: panel }
          Widgets.Battery {}
          // Widgets.Network {}
        }
        
      }
    }
  }
}
