import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs
import qs.widgets as Widgets

PanelWindow {
  id: panel;
  required property var modelData;
  screen: modelData;

  // Overlay (not Top) so the expanded/panel states draw above regular
  // windows even where they overhang past the bar's reserved space below.
  // That deliberately outranks fullscreen content too — except a fullscreen
  // video/game is exactly the case where you don't want the bar sitting on
  // top uninvited, so it hides itself entirely while the active workspace
  // on this screen has a fullscreen window.
  WlrLayershell.layer: WlrLayer.Overlay;
  WlrLayershell.namespace: "quickshell:resonate:bar";

  property HyprlandMonitor monitor: Hyprland.monitorFor(screen);
  readonly property bool screenFullscreen: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.hasFullscreen : false;
  visible: !screenFullscreen;

  // Otherwise a panel left open before going fullscreen would just be
  // sitting there, stale, the moment the bar reappears.
  onScreenFullscreenChanged: if (screenFullscreen) {
    centerWidget.panelOpen = false;
    powerWidget.panelOpen = false;
  }

  anchors { top: true; left: true; right: true; }
  color: "transparent";

  property alias panelOpen: centerWidget.panelOpen;
  property alias powerPanelOpen: powerWidget.panelOpen;
  readonly property bool anyPanelOpen: panelOpen || powerPanelOpen;

  // Only one panel open at a time — besides being the more sensible
  // quick-settings-style UX, having both open at once made the window
  // (sized to fit whichever is open, see implicitHeight below) taller,
  // which widens the HyprlandFocusGrab's "inside" region below and made
  // outside clicks miss more often.
  onPanelOpenChanged: if (panelOpen) powerWidget.panelOpen = false;
  onPowerPanelOpenChanged: if (powerPanelOpen) centerWidget.panelOpen = false;

  // Click-outside-to-close, via Hyprland's own compositor-level grab —
  // NOT a full-screen invisible window of our own (that was tried first:
  // it technically worked for catching an outside click, but as a side
  // effect it silently absorbed *every* pointer event across the whole
  // screen while a panel was open, including scroll — so scrolling
  // anywhere, not just over this widget, stopped working until the panel
  // closed. HyprlandFocusGrab has Hyprland itself watch for interaction
  // outside `windows` and tell us via `cleared`, so events we don't care
  // about are never intercepted by us in the first place — they just go
  // to whatever's actually there, same as if the panel weren't open.
  HyprlandFocusGrab {
    windows: [panel];
    active: panel.anyPanelOpen;
    onCleared: {
      centerWidget.panelOpen = false;
      powerWidget.panelOpen = false;
    }
  }

  // The window really does resize for a hover or a panel open — but only
  // as a single jump right as it starts, and another single jump after
  // things have fully settled back down on the way out (see CenterWidget's
  // windowExpanded/targetHeight). It's never resized mid-animation, which
  // is what caused the earlier stutter: each resize of a real layer-shell
  // surface is a full Wayland reconfigure/realloc, not just a repaint, so
  // doing that every animation frame is what jittered. Content still does
  // the actual gradual grow/shrink you watch, animating freely within
  // whichever size the window is currently jumped to. This never reaches
  // anywhere near full screen height (just enough to fit whichever panel
  // is open), so it doesn't hit the exclusive-zone problem above.
  //
  // barConnectorHeight is not added on top here — each island now starts
  // flush at y=0 (topMargin: 0, same as the connecting strip) so its own
  // content overlaps down through the connector band rather than sitting
  // below it; targetHeight/collapsedSize already account for that band,
  // so adding barConnectorHeight again would over-reserve space.
  // barVerticalMargin is kept as the breathing room below the tallest
  // current content.
  implicitHeight: Math.max(centerWidget.targetHeight, powerWidget.targetHeight) + Theme.barVerticalMargin;

  // The space Hyprland reserves for the bar is pinned to the widgets'
  // collapsed footprint, so hovering/opening a panel never reflows tiled
  // windows — the expanded content simply paints over them, on the Overlay
  // layer above.
  exclusionMode: ExclusionMode.Normal;
  exclusiveZone: Math.max(centerWidget.collapsedSize, powerWidget.collapsedSize) + Theme.barVerticalMargin;

  // Only the bar widgets' current (animated) bounds ever accept pointer
  // input — the rest of this window is click-through, always, even while a
  // panel is open. centerWidget/powerWidget's own bounds already track
  // whatever they're currently showing (collapsed pill, hover-expanded
  // pill, or — see CenterWidget's targetWidth/targetHeight — the open
  // panel itself), so masking against the holders rather than the leaf
  // widgets covers all three without a null/"accept everywhere" case.
  // Going wide-open while a panel was open used to be how a click on the
  // still-full-width-but-visually-empty part of this window got swallowed
  // by our own surface instead of reaching HyprlandFocusGrab as "outside".
  // connectorStrip is deliberately not in this mask — it's purely visual,
  // and its full window width would otherwise make everything above the
  // islands click-through-but-not-really across the whole bar.
  mask: barMask;
  Region {
    id: barMask;
    Region { item: centerWidget; }
    Region { item: workspacesWidget; }
    Region { item: powerWidget; }
  }

  // The connecting strip the three islands hang from as notches — same
  // frosted-glass fill as each island (CurrentTheme.surface, picked up by
  // the compositor blur rule in appearance.lua), flush against the
  // screen's top edge with no margin and no rounding, so together with
  // each island's own squared-off top corners (see the corner-patch
  // Rectangle in Workspaces/Clock/PowerStatus) the whole assembly reads as
  // one continuous shape rather than three separate floating pills.
  //
  // Two segments, only in the *gaps* between islands — not one rectangle
  // spanning underneath them too. CurrentTheme.surface is translucent, so
  // a segment drawn under an island stacked two semi-transparent layers
  // of the same color there, compositing visibly darker than either the
  // gaps (one layer) or the island's own interior (also one layer) — a
  // real seam, not a rounding error.
  //
  // No horizontal margin against the fillets: a margin here was tried and
  // reverted — each NotchFillet occupies y >= barConnectorHeight (it's
  // positioned to start exactly at the strip's own bottom edge and grow
  // downward into the notch), while this strip occupies y < that same
  // line, so the two never actually overlap in Y regardless of X. Adding
  // a margin didn't prevent a real overlap; it just carved a gap-shaped
  // hole between the strip's edge and the fillet's own fill (which itself
  // only reaches the strip's edge right at the island's corner, not
  // across its whole bounding box — a plain quarter-disk, not a full
  // square).
  //
  // NOT anchored to centerWidget/powerWidget's own left/right: those
  // *wrapper* items resize in a single discrete jump the instant a hover/
  // panel-open starts (see the implicitHeight comment above — a real
  // layer-shell reconfigure every animation frame is what caused the
  // earlier stutter), while the actual visible content inside
  // (clockContent/powerContent, or the open panel once panelOpen/
  // powerPanelOpen) grows toward that new size gradually via its own
  // Behavior. Anchoring the strip to the wrapper's edge made it snap to
  // the fully-expanded position instantly, while the visible content
  // (and its NotchFillet, a child of it) was still mid-animation and
  // visibly narrower — a real gap between the strip's end and the
  // fillet, live and reproducible, not a screenshot artifact.
  //
  // clockLeftEdge etc. below compute each *currently visible* piece's
  // own edge instead — wrapper.x + content.x (and + content.width for
  // the far edge) — which cancels the wrapper's jump out algebraically
  // (Clock/ControlPanel's horizontalCenter anchoring and PowerStatus/
  // PowerPanel's right anchoring both keep the same reference point
  // fixed regardless of the wrapper's own width), leaving an expression
  // that depends only on the visible content's own Behavior-animated
  // size. Once a panel is open its own content.x is 0 by the same
  // centering logic (CenterWidget's panelLoader ends up exactly as wide
  // as its now panel-sized wrapper, so there's no centering offset left)
  // — panelOpen/powerPanelOpen just pick which content is currently the
  // real visible one, pill or panel.
  readonly property real clockLeftEdge: centerWidget.x + (panelOpen ? 0 : clockContent.x);
  readonly property real clockRightEdge: centerWidget.x + (panelOpen ? centerWidget.width : clockContent.x + clockContent.width);
  readonly property real powerLeftEdge: powerWidget.x + (powerPanelOpen ? 0 : powerContent.x);

  Rectangle {
    y: 0;
    x: workspacesWidget.x + workspacesWidget.width;
    width: panel.clockLeftEdge - x;
    height: Theme.barConnectorHeight;
    color: CurrentTheme.surface;
  }
  Rectangle {
    y: 0;
    x: panel.clockRightEdge;
    width: panel.powerLeftEdge - x;
    height: Theme.barConnectorHeight;
    color: CurrentTheme.surface;
  }

  Widgets.Workspaces {
    id: workspacesWidget;
    screen: panel.screen;

    anchors {
      left: parent.left;
      leftMargin: Theme.barHorizontalMargin * 2;
      top: parent.top;
      topMargin: 0;
    }
  }

  Widgets.CenterWidget {
    id: centerWidget;
    collapsedSize: clockContent.collapsedSize;
    contentCollapsedWidth: clockContent.collapsedWidth;
    contentExpandedWidth: clockContent.expandedWidth;
    contentExpandedHeight: clockContent.expandedHeight;
    contentExpanded: clockContent.expanded;
    contentSuppressesTap: clockContent.suppressPanelOpen;
    panelContent: controlPanelComponent;

    anchors {
      top: parent.top;
      topMargin: 0;
      horizontalCenter: parent.horizontalCenter;
    }

    Widgets.Clock { id: clockContent; }
  }

  Widgets.CenterWidget {
    id: powerWidget;
    collapsedSize: powerContent.collapsedSize;
    contentCollapsedWidth: powerContent.collapsedWidth;
    contentExpandedWidth: powerContent.expandedWidth;
    contentExpandedHeight: powerContent.expandedHeight;
    contentExpanded: powerContent.expanded;
    contentSuppressesTap: powerContent.suppressNextTap;
    contentTapExclusions: powerContent.controlsExclusions;
    panelContent: powerPanelComponent;

    anchors {
      top: parent.top;
      topMargin: 0;
      right: parent.right;
      rightMargin: Theme.barHorizontalMargin;
    }

    Widgets.PowerStatus { id: powerContent; }
  }

  // The concave fillets smoothing each island's seam with the connecting
  // strip above (see NotchFillet.qml) now live as children of each island
  // component itself (Workspaces/Clock/PowerStatus), positioned via local
  // anchors off that island's own edges — not here as external siblings —
  // so they track content-driven size changes (e.g. Clock's hover/
  // notification expand) in lockstep with zero animation lag.

  Component {
    id: controlPanelComponent;
    Widgets.ControlPanel {}
  }

  Component {
    id: powerPanelComponent;
    Widgets.PowerPanel {}
  }
}
