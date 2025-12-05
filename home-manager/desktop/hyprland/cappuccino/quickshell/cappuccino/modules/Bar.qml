import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell

import "../widgets" as Widgets

Scope{

  Variants {
    model: Quickshell.screens;

    delegate: Component {
      PanelWindow {
        id: panel;

        // configurable properties
        property int widgetHeight: 30;
        property int verticalMargin: 5;
        property int horizontalMargin: 5;
        color: "transparent";

        // calculated properties
        required property var modelData;
        screen: modelData;
        anchors { top: true; left: true; right: true; }
        implicitHeight: widgetHeight + verticalMargin * 2;

        // Modules
        Workspaces {
          screen: modelData;
          anchors {
            left: parent.left;
            leftMargin: horizontalMargin;
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
          spacing: 5;

          width: Math.min(
            this.implicitWidth, 
            panel.width / 3
          ); 

          anchors {
            right: parent.right;
            rightMargin: horizontalMargin;
            verticalCenter: parent.verticalCenter;
          }
          
          Widgets.Systemtray {}
          Widgets.Battery {}
        }
        
      }
    }
  }
}
