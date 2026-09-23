import Quickshell
import Quickshell.Hyprland
import QtQuick

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

  A chevron handle at the far left opens the workspaces panel
  (WorkspacesPanel.qml) — wired up in Bar.qml via ResizeBox, same as the
  clock/power panels. This widget exposes the ResizeBox size contract
  (collapsedSize/collapsedWidth/expanded/…) for that; it has no hover-expand
  state of its own, so the "expanded" sizes just equal the collapsed ones.

  Required property:
    - screen: The ShellScreen this widget is associated with,
              used to determine which workspaces are on this monitor.
*/

Item {
  id: workspacesWidget;
  required property ShellScreen screen;
  property HyprlandMonitor monitor: Hyprland.monitorFor(screen);

  signal panelRequested();

  height: Theme.barHeight;

  // --- ResizeBox size contract -------------------------------------
  readonly property int collapsedSize: Theme.barHeight;
  readonly property int collapsedWidth: implicitWidth;
  readonly property bool expanded: false;
  readonly property int expandedWidth: implicitWidth;
  readonly property int expandedHeight: collapsedSize;

  readonly property real chevronWidth: workspacesWidget.dotSize + 4;
  implicitWidth: chevronWidth + dots.implicitWidth + Theme.defaultSpacing * 2;

  readonly property real dotSize: Theme.barHeight - Theme.defaultSpacing * 2;

  // Just the content now — the painted surface (fill + shadow + the outward
  // curve into the connecting strip) is BarSurface, one shared shape drawn
  // once for the whole bar in Bar.qml.
  Item {
    anchors.fill: parent;

    // Panel handle — a downward chevron at the far left. Tapping it asks
    // Bar.qml (via ResizeBox) to open the workspaces panel.
    Item {
      id: chevronHandle;
      width: workspacesWidget.chevronWidth;
      height: parent.height;
      x: Theme.defaultSpacing / 2;

      Text {
        anchors.centerIn: parent;
        text: String.fromCodePoint(0xf0140); // md-chevron_down
        font.family: Theme.iconFontFamily;
        font.pixelSize: Theme.iconSize;
        color: chevronHover.hovered ? CurrentTheme.text : CurrentTheme.subtext;
      }

      HoverHandler { id: chevronHover; }
      TapHandler { onTapped: workspacesWidget.panelRequested(); }
    }

    WorkspaceDots {
      id: dots;
      monitor: workspacesWidget.monitor;
      dotSize: workspacesWidget.dotSize;
      anchors.verticalCenter: parent.verticalCenter;
      x: Theme.defaultSpacing / 2 + workspacesWidget.chevronWidth + Theme.defaultSpacing / 2;
    }
  }
}
