import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs
import qs.widgets as Widgets
import qs.services as Services

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

  // OnDemand so a click on a text field in an open panel (the Wi-Fi password
  // input) can take keyboard focus — without it, the layer surface never
  // receives key events. Idle/hover states don't grab focus with this mode.
  // The launcher and the assistant need their text field focused with no
  // click (and, for the launcher, arrow/tab keys captured), so they go
  // Exclusive while open on this screen.
  WlrLayershell.keyboardFocus:
    ((panel.hotkeyAppOpen || panel.sessionConfirming) && panel.isFocusedScreen) ? WlrKeyboardFocus.Exclusive
    : panel.anyPanelOpen ? WlrKeyboardFocus.OnDemand
    : WlrKeyboardFocus.None;

  property HyprlandMonitor monitor: Hyprland.monitorFor(screen);
  readonly property bool isFocusedScreen: !!panel.monitor && panel.monitor.focused;

  // A page opened by a global shortcut (SUPER+Space launcher, SUPER+A assistant).
  readonly property bool hotkeyAppOpen: Services.LauncherService.open || Services.AssistantService.open;

  // Keep CaffeineService (its systemd-inhibit process) and
  // PlatformProfileService (its AC<->battery auto-switching) alive from the
  // always-instantiated bar, not just while the power panel is open.
  readonly property bool _caffeine: Services.CaffeineService.active;
  readonly property string _powerProfile: Services.PlatformProfileService.profile;
  readonly property bool screenFullscreen: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.hasFullscreen : false;

  // A session confirm (power off etc.) opens in this screen's power slot when
  // it's the focused one; SessionOverlay only dims the screens underneath.
  readonly property bool sessionConfirming: Services.SessionService.pending !== "" && powerSlot.panelOpen;
  Connections {
    target: Services.SessionService;
    function onPendingChanged() {
      if (Services.SessionService.pending === "") powerSlot.panelOpen = false;
      else if (panel.isFocusedScreen) powerSlot.panelOpen = true;
    }
  }
  visible: !screenFullscreen || (Services.SessionService.pending !== "" && panel.isFocusedScreen);

  // Otherwise a panel left open before going fullscreen would just be
  // sitting there, stale, the moment the bar reappears.
  onScreenFullscreenChanged: if (screenFullscreen) {
    centerSlot.panelOpen = false;
    powerSlot.panelOpen = false;
    workspacesSlot.panelOpen = false;
  }

  anchors { top: true; left: true; right: true; }
  color: "transparent";

  property alias panelOpen: centerSlot.panelOpen;
  property alias powerPanelOpen: powerSlot.panelOpen;
  property alias workspacesPanelOpen: workspacesSlot.panelOpen;
  readonly property bool anyPanelOpen: panelOpen || powerPanelOpen || workspacesPanelOpen;

  // Only one panel open at a time — besides being the more sensible
  // quick-settings-style UX, having both open at once made the window
  // (sized to fit whichever is open, see implicitHeight below) taller,
  // which widens the HyprlandFocusGrab's "inside" region below and made
  // outside clicks miss more often.
  onPanelOpenChanged: if (panelOpen) { powerSlot.panelOpen = false; workspacesSlot.panelOpen = false; }
  onPowerPanelOpenChanged: if (powerPanelOpen) { centerSlot.panelOpen = false; workspacesSlot.panelOpen = false; }
  onWorkspacesPanelOpenChanged: if (workspacesPanelOpen) { centerSlot.panelOpen = false; powerSlot.panelOpen = false; }

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
    // A click on a pill is what normally starts a panel grab; the launcher
    // and assistant open from a keybind with the pointer elsewhere, so an
    // immediately-live grab reads that as "clicked outside" and fires
    // `cleared` at once. Wait until the page is interacted with (pointer
    // enters the panel) or a short grace period passes — `hotkeyGrabReady`.
    // Off during a session confirm: its dim (SessionOverlay) takes the
    // outside clicks, and a grab armed by a keybind would clear at once.
    active: panel.anyPanelOpen && Services.SessionService.pending === ""
      && (!panel.hotkeyAppOpen || panel.hotkeyGrabReady);
    onCleared: {
      Services.SessionService.cancel();
      centerSlot.panelOpen = false;
      powerSlot.panelOpen = false;
      workspacesSlot.panelOpen = false;
    }
  }

  // Launcher / assistant ⇄ centre box. Opening one (global shortcut) morphs
  // this screen's centre box onto its page — but only on the focused
  // monitor. Any close route runs back through appDismissed.
  property bool hotkeyGrabReady: false;
  Timer { id: hotkeyGrabArm; interval: 600; onTriggered: panel.hotkeyGrabReady = true; }

  function syncHotkeyApp(appId, isOpen) {
    if (isOpen) {
      panel.hotkeyGrabReady = false;
      if (panel.isFocusedScreen) { centerSlot.openApp(appId); hotkeyGrabArm.restart(); }
    } else {
      hotkeyGrabArm.stop();
      panel.hotkeyGrabReady = false;
      centerSlot.closeApp(appId);
    }
  }

  Connections {
    target: Services.LauncherService;
    function onOpenChanged() { panel.syncHotkeyApp("launcher", Services.LauncherService.open); }
  }
  Connections {
    target: Services.AssistantService;
    function onOpenChanged() { panel.syncHotkeyApp("assistant", Services.AssistantService.open); }
  }
  Connections {
    target: centerSlot;
    function onAppDismissed(appId) {
      if (appId === "launcher") Services.LauncherService.open = false;
      else if (appId === "assistant") Services.AssistantService.open = false;
    }
  }

  // Fixed forever — no debounced windowExpanded/settleTimer machinery
  // anymore, because there's nothing left to debounce: this never resizes
  // after startup, so a real layer-shell reconfigure only ever happens
  // once. Content still does all the actual gradual grow/shrink you watch,
  // animating freely within this fixed-size surface. Generous enough for
  // the tallest possible panel (maxPanelContentHeight, the same cap every
  // panel already respects) plus the same breathing room below content
  // barVerticalMargin already provided.
  implicitHeight: Theme.maxPanelHeight + Theme.panelShadowRoom;

  // The space Hyprland reserves for the bar is pinned to the slots'
  // collapsed footprint (unchanged by the window itself now being fixed at
  // its generous full height), so hovering/opening a panel never reflows
  // tiled windows — the expanded content simply paints over them, on the
  // Overlay layer above.
  exclusionMode: ExclusionMode.Normal;
  exclusiveZone: Math.max(workspacesContent.collapsedSize, clockContent.collapsedSize, powerContent.collapsedSize) + Theme.barVerticalMargin;

  // Only the bar slots' current (animated) bounds ever accept pointer
  // input — the rest of this window is click-through, always, even while a
  // panel is open. Each slot's own bounds already track whatever it's
  // currently showing (collapsed pill, hover-expanded pill, or the open
  // panel), so masking against the slots rather than their leaf content
  // covers all three without a null/"accept everywhere" case. barSurface is
  // deliberately not in this mask — it's purely visual, and its full
  // bounding box would otherwise make everything above the slots
  // click-through-but-not-really across the whole bar.
  mask: barMask;
  Region {
    id: barMask;
    Region { item: centerSlot; }
    Region { item: workspacesSlot; }
    Region { item: powerSlot; }
  }

  // The three slots' current (live, animated) bounds — the only thing
  // barOutline() below depends on. Each slot's own on-screen size (Slot.qml)
  // is already a direct, non-duplicated read of whichever content (pill or
  // panel) is currently active, so this needs no debouncing and can't
  // disagree with what's actually on screen. maxRadius follows the same
  // pill-vs-panel switch every panel already used on its own IslandSurface.
  readonly property var slots: [
    {
      x: workspacesSlot.x, width: workspacesSlot.implicitWidth, height: workspacesSlot.implicitHeight,
      maxRadius: (workspacesSlot.panelOpen || workspacesSlot.panelClosing) ? 18 : 16,
    },
    {
      x: centerSlot.x, width: centerSlot.implicitWidth, height: centerSlot.implicitHeight,
      maxRadius: (centerSlot.panelOpen || centerSlot.panelClosing) ? 18 : 16,
    },
    {
      x: powerSlot.x, width: powerSlot.implicitWidth, height: powerSlot.implicitHeight,
      maxRadius: (powerSlot.panelOpen || powerSlot.panelClosing) ? 18 : 16,
    },
  ];

  // Builds the whole bar's silhouette as one closed SVG path: each slot's
  // own rounded-bottom body, joined to its neighbours by a thin strip with
  // a concave "nodge" arc at each junction — the same curve the old
  // standalone Nodge.qml drew, now just one segment of a single continuous
  // outline instead of a separately-drawn, separately-antialiased item.
  // Traversed clockwise: flat across the top (every slot's own top is
  // square, and the strip sits at that same y=0 line, so the whole top edge
  // is one straight line), then right-to-left along the bottom, weaving
  // through each slot's own convex corners and each gap's concave ones.
  //
  // Each corner arc's center is placed exactly at the sharp corner it
  // replaces — a *convex* rounded corner (sweep-flag 1) carves the corner
  // away; a *concave* nodge (sweep-flag 0 — confirmed live: 1 here drew an
  // extra convex bulb instead of the intended inward curve) fills the notch
  // back in instead.
  //
  // One shared radius (R below) for every bottom corner and every nodge in
  // the whole bar, not a size picked independently per corner — requested
  // live: a notch's two bottom corners and its connecting nodge(s) should
  // never mismatch in size. Since a middle slot's own two bottom corners
  // have to match each other, that transitively ties its two (otherwise
  // unrelated) nodges together too, and from there to the two end slots'
  // own outer corners as well — in practice this ends up being one number
  // for the entire assembly, capped wherever a short pill would otherwise
  // be too short for a full corner radius *and* a full nodge tangent below
  // it (they're both trying to use the same few pixels of a slot's own
  // straight edge). A plain derived expression over already-`Behavior`-
  // animated widths/heights, so it eases smoothly on its own — no separate
  // animation needed.
  function barOutline(slots) {
    if (!slots || slots.length === 0) return "";
    var S = Theme.barConnectorHeight;
    var n = slots.length;
    var first = slots[0];
    var last = slots[n - 1];

    var R = Theme.nodgeRadius;
    for (var i = 0; i < n; i++) R = Math.min(R, slots[i].maxRadius, slots[i].height / 2);
    for (var k = 0; k < n - 1; k++) {
      var gap = Math.max(0, slots[k + 1].x - (slots[k].x + slots[k].width));
      R = Math.min(R, gap / 2, (slots[k].height - S) / 2, (slots[k + 1].height - S) / 2);
    }
    R = Math.max(0, R);

    var d = "M " + first.x + " 0 ";
    d += "L " + (last.x + last.width) + " 0 ";

    for (var i = n - 1; i >= 0; i--) {
      var s = slots[i];
      var right = s.x + s.width;
      var hasRightNodge = i < n - 1;
      var topY = hasRightNodge ? (S + R) : 0;

      if (s.height - R > topY) d += "L " + right + " " + (s.height - R) + " ";
      d += "A " + R + " " + R + " 0 0 1 " + (right - R) + " " + s.height + " ";
      d += "L " + (s.x + R) + " " + s.height + " ";
      d += "A " + R + " " + R + " 0 0 1 " + s.x + " " + (s.height - R) + " ";

      if (i === 0) {
        d += "L " + s.x + " 0 Z";
      } else {
        d += "L " + s.x + " " + (S + R) + " ";
        d += "A " + R + " " + R + " 0 0 0 " + (s.x - R) + " " + S + " ";
        var prev = slots[i - 1];
        var prevRight = prev.x + prev.width;
        d += "L " + (prevRight + R) + " " + S + " ";
        d += "A " + R + " " + R + " 0 0 0 " + prevRight + " " + (S + R) + " ";
      }
    }
    return d;
  }

  // The one background shape for the whole bar — replaces the old
  // Nodge/IslandSurface/connecting-strip trio. Same frosted fill
  // (CurrentTheme.surface, picked up by the compositor blur rule in
  // appearance.lua) as before, just painted once instead of six-plus times:
  // a single fill with a single antialiased outer boundary can't seam
  // against itself the way several independently-drawn translucent pieces
  // could (and did — see the plan for why that hard line between the strip
  // and the nodges was actually happening).
  Shape {
    id: barSurface;
    anchors.fill: parent;
    preferredRendererType: Shape.CurveRenderer;

    layer.enabled: true;
    layer.effect: MultiEffect {
      // Always on, no resizing-gated fade — confirmed live (brightness-
      // sampled recordings) that fade was contributing to a subtle flash
      // during resize. It existed to stop six *separate* shadowed pieces
      // from visibly warping relative to each other mid-resize; with one
      // continuous shape now, there's only one silhouette for the shadow
      // to track and it's always the true current one, so that reason no
      // longer applies.
      shadowEnabled: true;
      shadowColor: Theme.shadowColor;
      shadowBlur: Theme.shadowBlur;
      shadowVerticalOffset: Theme.shadowVerticalOffset;
    }

    ShapePath {
      fillColor: CurrentTheme.surface;
      strokeWidth: -1;
      PathSvg { path: panel.barOutline(panel.slots); }
    }
  }

  Widgets.Slot {
    id: workspacesSlot;
    panelAlign: "left";
    contentItem: workspacesContent;
    // Only the chevron handle opens the panel — the workspace dots keep
    // their own tap-to-activate.
    contentSuppressesTap: true;
    panelContent: workspacesPanelComponent;
    panelScreenHeight: panel.screen ? panel.screen.height : 0;
    panelMonitor: panel.monitor;

    anchors {
      left: parent.left;
      leftMargin: Theme.barHorizontalMargin * 2;
      top: parent.top;
      topMargin: 0;
    }

    Widgets.Workspaces {
      id: workspacesContent;
      screen: panel.screen;
      onPanelRequested: workspacesSlot.panelOpen = true;
    }
  }

  Widgets.Slot {
    id: centerSlot;
    contentItem: clockContent;
    contentSuppressesTap: clockContent.suppressPanelOpen;
    panelContent: controlPanelComponent;
    panelScreenHeight: panel.screen ? panel.screen.height : 0;

    anchors {
      top: parent.top;
      topMargin: 0;
      horizontalCenter: parent.horizontalCenter;
    }

    // Arm the click-outside grab the moment the pointer reaches the open
    // launcher/assistant (the timer is just the never-touched-the-mouse fallback).
    HoverHandler {
      onHoveredChanged: if (hovered && panel.hotkeyAppOpen) panel.hotkeyGrabReady = true;
    }

    Widgets.Clock { id: clockContent; }
  }

  Widgets.Slot {
    id: powerSlot;
    contentItem: powerContent;
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

  Component {
    id: controlPanelComponent;
    Widgets.ControlPanel {}
  }

  Component {
    id: powerPanelComponent;
    Widgets.SystemPanel {}
  }

  Component {
    id: workspacesPanelComponent;
    Widgets.WorkspacesPanel {}
  }
}
