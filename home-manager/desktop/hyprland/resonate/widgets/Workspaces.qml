import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects

import qs

/*
  A workspace indicator widget, ported from cappuccino's version.
  The indicators each represent a workspace.

  > A sliding accent-colored indicator shows the active workspace on this
    monitor (CurrentTheme.accent — configurable in the control panel).
    - On same-monitor workspace switch: the indicator slides to the new dot.
    - On monitor focus change: it dims rather than switching palettes, so
      this keeps working regardless of which Catppuccin flavor is active.
  > Inactive workspaces on the current monitor: CurrentTheme.text.
  > Workspaces on other monitors: dimmer (CurrentTheme.subtext).
  > New workspaces sweep in (width + opacity animation).

  Required property:
    - screen: The ShellScreen this widget is associated with,
              used to determine which workspaces are on this monitor.
*/

Rectangle {
  id: workspacesWidget;
  required property ShellScreen screen;
  property HyprlandMonitor monitor: Hyprland.monitorFor(screen);

  height: Theme.barHeight;
  radius: height / 2;
  color: CurrentTheme.surface;
  border.width: 1;
  border.color: CurrentTheme.border;

  layer.enabled: true;
  layer.effect: MultiEffect {
    shadowEnabled: true;
    shadowColor: Theme.shadowColor;
    shadowBlur: Theme.shadowBlur;
    shadowVerticalOffset: Theme.shadowVerticalOffset;
  }

  implicitWidth: workspaceRow.implicitWidth + Theme.defaultSpacing * 2;

  readonly property real dotSize: Theme.barHeight - Theme.defaultSpacing * 2;

  // Index of the active workspace on this monitor within the Repeater.
  property int activeIndex: {
    if (!monitor || !monitor.activeWorkspace) return -1;
    for (var i = 0; i < wsRepeater.count; i++) {
      var item = wsRepeater.itemAt(i);
      if (item && item.modelData === monitor.activeWorkspace) return i;
    }
    return -1;
  }

  Row {
    id: workspaceRow;
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
        color: onCurrentMonitor ? CurrentTheme.text : CurrentTheme.subtext;

        Text {
          // Hide number on the active dot; the sliding indicator renders it instead.
          visible: !wsDot.modelData.active;
          text: onCurrentMonitor ? wsDot.modelData.id : "";
          anchors.centerIn: parent;
          color: CurrentTheme.background;
          font.pixelSize: 12;
          font.weight: Font.Medium;
        }

        TapHandler {
          onTapped: wsDot.modelData.activate();
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
  // Slides between dots on same-monitor workspace switch. Dims on
  // unfocused monitors rather than switching to a different palette, so it
  // stays correct no matter which flavor/accent is currently active.
  Rectangle {
    id: activeIndicator;
    width: workspacesWidget.dotSize;
    height: width;
    radius: height / 2;
    color: CurrentTheme.accent;
    opacity: (monitor && monitor.focused) ? 1 : 0.55;
    y: (workspacesWidget.height - height) / 2;

    x: {
      var idx = workspacesWidget.activeIndex;
      if (idx < 0) return 0;
      var item = wsRepeater.itemAt(idx);
      if (!item) return 0;
      // Row is anchored at leftMargin: Theme.defaultSpacing from the pill's left edge.
      return Theme.defaultSpacing + item.x;
    }

    Behavior on x       { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on color   { ColorAnimation  { duration: 180 } }

    Text {
      anchors.centerIn: parent;
      color: CurrentTheme.background;
      font.pixelSize: 12;
      font.weight: Font.Bold;
      text: (monitor && monitor.activeWorkspace) ? monitor.activeWorkspace.id : "";
    }
  }
}
