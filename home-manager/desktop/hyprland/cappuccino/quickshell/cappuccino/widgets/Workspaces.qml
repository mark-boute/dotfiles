import Quickshell
import Quickshell.Hyprland
import QtQuick

import qs
import qs.shapes as Shapes

/*
  A workspace indicator widget.
  The indicators each represent a workspace.

  > A sliding peach indicator shows the active workspace on this monitor.
    - On same-monitor workspace switch: the indicator slides to the new dot.
    - On monitor focus change: the indicator fades in/out via monitor.focused.
  > Inactive workspaces on the current monitor: rosewater.
  > Workspaces on other monitors: grey (overlay1).
  > New workspaces sweep in (width + opacity animation).

  Required property:
    - screen: The ShellScreen this widget is associated with,
              used to determine which workspaces are on this monitor.
*/

Shapes.MenuPill {
  required property ShellScreen screen;
  property HyprlandMonitor monitor: Hyprland.monitorFor(screen);
  id: workspacesWidget;
  implicitWidth: workspace.implicitWidth + Theme.defaultSpacing * 2;

  readonly property real dotSize: Theme.barHeight - Theme.defaultSpacing * 2;

  // Index of the active workspace on this monitor within the Repeater.
  // Depends on monitor.activeWorkspace so it re-evaluates on workspace switch.
  property int activeIndex: {
    if (!monitor || !monitor.activeWorkspace) return -1;
    for (var i = 0; i < wsRepeater.count; i++) {
      var item = wsRepeater.itemAt(i);
      if (item && item.modelData === monitor.activeWorkspace) return i;
    }
    return -1;
  }

  Row {
    id: workspace;
    spacing: Theme.defaultSpacing;
    anchors {
      left: parent.left;
      verticalCenter: parent.verticalCenter;
      leftMargin: Theme.defaultSpacing;
    }

    Repeater {
      id: wsRepeater;
      model: Hyprland.workspaces;

      Rectangle {
        id: wsDot;
        required property HyprlandWorkspace modelData;
        property bool onCurrentMonitor: modelData.monitor === monitor;

        height: workspacesWidget.dotSize;
        width: implicitWidth;
        implicitWidth: 0;
        opacity: 0;
        radius: workspacesWidget.dotSize / 2;

        // Dots are always inactive — the sliding indicator handles the active highlight.
        color: onCurrentMonitor ? Theme.macchiato.rosewater : Theme.macchiato.overlay1;

        Text {
          // Hide number on the active dot; the sliding indicator renders it instead.
          visible: !wsDot.modelData.active;
          text: onCurrentMonitor ? wsDot.modelData.id : "";
          anchors.centerIn: parent;
          color: Theme.macchiato.base;
          font.pixelSize: 12;
          font.weight: Font.Medium;
        }

        MouseArea {
          anchors.fill: parent;
          onClicked: modelData.activate();
        }

        Component.onCompleted: appearAnimation.start();

        ParallelAnimation {
          id: appearAnimation;
          NumberAnimation {
            target: wsDot; property: "implicitWidth";
            to: workspacesWidget.dotSize;
            duration: 240; easing.type: Easing.OutCubic;
          }
          NumberAnimation {
            target: wsDot; property: "opacity";
            to: 1; duration: 200; easing.type: Easing.OutCubic;
          }
        }
      }
    }
  }

  // Sliding active workspace indicator — overlaid on top of the Row.
  // Slides between dots on same-monitor workspace switch.
  // Focused monitor: bright latte.peach. Unfocused: dimmer macchiato.peach — still
  // readable so you can see which workspace is active on each display.
  Rectangle {
    id: activeIndicator;
    width: workspacesWidget.dotSize;
    height: width;
    radius: height / 2;
    color: (monitor && monitor.focused) ? Theme.latte.peach : Theme.macchiato.peach;
    y: (workspacesWidget.height - height) / 2;

    x: {
      var idx = workspacesWidget.activeIndex;
      if (idx < 0) return 0;
      var item = wsRepeater.itemAt(idx);
      if (!item) return 0;
      // Row is anchored at leftMargin: Theme.defaultSpacing from the pill's left edge.
      return Theme.defaultSpacing + item.x;
    }

    Behavior on x {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on color {
      ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Text {
      anchors.centerIn: parent;
      color: (monitor && monitor.focused) ? Theme.latte.base : Theme.macchiato.base;
      font.pixelSize: 12;
      font.weight: Font.Bold;
      text: (monitor && monitor.activeWorkspace) ? monitor.activeWorkspace.id : "";

      Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
      }
    }
  }
}
