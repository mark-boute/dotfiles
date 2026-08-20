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
  // A "notch" hanging from the bar's connecting strip (Bar.qml) — no
  // border (would draw a seam right where this meets the strip). The
  // smooth outward-curving transition into the strip itself is drawn by
  // rightFillet below, a child of this Rectangle (not placed externally
  // by Bar.qml) so it tracks this island's own size/position with zero
  // animation lag — not by this Rectangle's own corners. Only on the
  // right: this is the leftmost island, flush with the strip's own left
  // edge, so there's no seam to smooth on the left.
  // Square top corners (the outward curve into the connecting strip is
  // drawn entirely by NotchFillet at the seam, not by rounding here) via
  // per-corner radius, not a same-color Rectangle painted over the top of
  // this one to flatten it — that approach stacked two translucent layers
  // of CurrentTheme.surface in the top band, compositing visibly darker
  // there than the single-layer rest of the pill (confirmed live: a sharp
  // horizontal color seam right at the patch's own edge).
  radius: Math.min(16, height / 2);
  topLeftRadius: 0;
  topRightRadius: 0;
  color: CurrentTheme.surface;

  layer.enabled: true;
  layer.effect: MultiEffect {
    shadowEnabled: true;
    shadowColor: Theme.shadowColor;
    shadowBlur: Theme.shadowBlur;
    shadowVerticalOffset: Theme.shadowVerticalOffset;
  }

  // Smooths the concave seam where this island's right edge meets the
  // connecting strip above (see NotchFillet.qml) — a child of this
  // Rectangle, positioned off its own width/height, so it stays in
  // lockstep if this island's size ever animates, with no cross-
  // component binding into Bar.qml.
  NotchFillet {
    id: rightFillet;
    mirrored: true;
    x: workspacesWidget.width;
    y: Theme.barConnectorHeight;
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
