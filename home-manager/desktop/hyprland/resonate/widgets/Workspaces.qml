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

  A chevron handle at the far left opens the workspaces panel
  (WorkspacesPanel.qml) — wired up in Bar.qml via CenterWidget, same as the
  clock/power panels. This widget exposes the CenterWidget size contract
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

  // --- CenterWidget size contract -------------------------------------
  readonly property int collapsedSize: Theme.barHeight;
  readonly property int collapsedWidth: implicitWidth;
  readonly property bool expanded: false;
  readonly property int expandedWidth: implicitWidth;
  readonly property int expandedHeight: collapsedSize;

  // A "notch" hanging from the bar's connecting strip (Bar.qml) — no
  // border (would draw a seam right where this meets the strip). The
  // smooth outward-curving transition into the strip itself is drawn by
  // rightFillet below, a child of this Item (not placed externally
  // by Bar.qml) so it tracks this island's own size/position with zero
  // animation lag — not by the surface Rectangle's own corners. Only on the
  // right: this is the leftmost island, flush with the strip's own left
  // edge, so there's no seam to smooth on the left.
  NotchFillet {
    id: rightFillet;
    mirrored: true;
    x: workspacesWidget.width;
    y: Theme.barConnectorHeight;
  }

  readonly property real chevronWidth: workspacesWidget.dotSize + 4;
  implicitWidth: chevronWidth + dots.implicitWidth + Theme.defaultSpacing * 2;

  readonly property real dotSize: Theme.barHeight - Theme.defaultSpacing * 2;

  // The actual painted notch surface — kept separate from workspacesWidget
  // above so its layer (shadow) texture bounds stay fixed at exactly this
  // Rectangle's own size, never needing to grow for the fillet above.
  Rectangle {
    id: workspacesSurface;
    anchors.fill: parent;

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

    // Panel handle — a downward chevron at the far left. Tapping it asks
    // Bar.qml (via CenterWidget) to open the workspaces panel.
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
