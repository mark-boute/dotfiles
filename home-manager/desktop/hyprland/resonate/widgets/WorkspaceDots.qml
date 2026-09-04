import Quickshell
import Quickshell.Hyprland
import QtQuick

import qs

// The workspace-dot row, shared verbatim between the collapsed bar island
// (Workspaces.qml) and the workspaces panel header (WorkspacesPanel.qml) so
// the two always show the exact same bullets.
//
//  > dots for this monitor's workspaces use CurrentTheme.text, other monitors'
//    dimmer (CurrentTheme.subtext); new ones sweep in (width + opacity).
//  > a sliding accent indicator marks the active workspace on `monitor`,
//    dimming (not repainting) when that monitor isn't focused.
Item {
  id: root;

  required property HyprlandMonitor monitor;
  property real dotSize: Theme.barHeight - Theme.defaultSpacing * 2;

  implicitWidth: dotRow.implicitWidth;
  implicitHeight: dotSize;

  property int activeIndex: {
    if (!monitor || !monitor.activeWorkspace) return -1;
    for (var i = 0; i < dotRepeater.count; i++) {
      var item = dotRepeater.itemAt(i);
      if (item && item.modelData === monitor.activeWorkspace) return i;
    }
    return -1;
  }

  Row {
    id: dotRow;
    spacing: Theme.defaultSpacing;
    anchors.verticalCenter: parent.verticalCenter;

    Repeater {
      id: dotRepeater;
      model: Hyprland.workspaces;

      Rectangle {
        id: wsDot;
        required property HyprlandWorkspace modelData;
        property bool onCurrentMonitor: modelData.monitor === root.monitor;

        height: root.dotSize;
        width: implicitWidth;
        implicitWidth: 0;
        opacity: 0;
        radius: root.dotSize / 2;

        // Dots are always inactive — the sliding indicator handles the active highlight.
        color: onCurrentMonitor ? CurrentTheme.text : CurrentTheme.subtext;

        Text {
          // Hide number on the active dot; the sliding indicator renders it instead.
          visible: !wsDot.modelData.active;
          text: wsDot.onCurrentMonitor ? wsDot.modelData.id : "";
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
            to: root.dotSize;
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

  Rectangle {
    id: activeIndicator;
    width: root.dotSize;
    height: width;
    radius: height / 2;
    color: CurrentTheme.accent;
    opacity: (root.monitor && root.monitor.focused) ? 1 : 0.55;
    y: (root.height - height) / 2;

    x: {
      var idx = root.activeIndex;
      if (idx < 0) return 0;
      var item = dotRepeater.itemAt(idx);
      if (!item) return 0;
      return item.x;
    }

    Behavior on x       { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on color   { ColorAnimation  { duration: 180 } }

    Text {
      anchors.centerIn: parent;
      color: CurrentTheme.background;
      font.pixelSize: 12;
      font.weight: Font.Bold;
      text: (root.monitor && root.monitor.activeWorkspace) ? root.monitor.activeWorkspace.id : "";
    }
  }
}
