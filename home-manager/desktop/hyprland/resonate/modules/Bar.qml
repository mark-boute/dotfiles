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
  implicitHeight: Math.max(centerWidget.targetHeight, powerWidget.targetHeight) + Theme.barVerticalMargin * 2;

  // The space Hyprland reserves for the bar is pinned to the widgets'
  // collapsed footprint, so hovering/opening a panel never reflows tiled
  // windows — the expanded content simply paints over them, on the Overlay
  // layer above.
  exclusionMode: ExclusionMode.Normal;
  exclusiveZone: Math.max(centerWidget.collapsedSize, powerWidget.collapsedSize) + Theme.barVerticalMargin * 2;

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
  mask: barMask;
  Region {
    id: barMask;
    Region { item: centerWidget; }
    Region { item: workspacesWidget; }
    Region { item: powerWidget; }
  }

  Widgets.Workspaces {
    id: workspacesWidget;
    screen: panel.screen;

    anchors {
      left: parent.left;
      leftMargin: Theme.barHorizontalMargin * 2;
      top: parent.top;
      topMargin: Theme.barVerticalMargin;
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
      topMargin: Theme.barVerticalMargin;
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
      topMargin: Theme.barVerticalMargin;
      right: parent.right;
      rightMargin: Theme.barHorizontalMargin;
    }

    Widgets.PowerStatus { id: powerContent; }
  }

  Component {
    id: controlPanelComponent;
    Widgets.ControlPanel {}
  }

  Component {
    id: powerPanelComponent;
    Widgets.PowerPanel {}
  }
}
