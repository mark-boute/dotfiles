import QtQuick

import qs

// A generic, auto-sizing box for the bar's three slots (Workspaces/Clock/
// Power). It doesn't know or care what `content` actually is beyond a small
// contract (collapsedSize/contentExpandedHeight/contentExpanded is no longer
// needed here — the real window is a fixed size now, see Bar.qml — so this
// only tracks on-screen size). Its own on-screen width/height are just a
// live read of whatever `contentItem`'s actual current size is — never a
// second, independently-animated copy of it. Clicking anywhere on it swaps
// to `panelContent` instead — the command center. Bar.qml reads this size
// directly to build its one shared background shape (BarSurface); this file
// owns no fill/shadow of its own at all.
Item {
  id: box;

  default property alias content: contentContainer.data;

  // The actual content instance (Clock/PowerStatus/Workspaces) — set
  // explicitly from Bar.qml. implicitWidth/Height below read this directly.
  property Item contentItem: null;

  // When content wants a tap to do something itself (e.g. Clock invoking a
  // notification's action) instead of opening the command center — for
  // when the *entire* box should behave that way right now.
  property bool contentSuppressesTap: false;

  // For when only specific sub-regions of the box should behave that way —
  // e.g. PowerStatus's own icon row, where each icon (mute, wifi, a tray
  // item, ...) needs to do its own thing on tap rather than also opening
  // the panel. A list rather than a single rect since the icon count
  // varies (system tray). Content-local coordinates (same origin as
  // contentContainer below).
  property var contentTapExclusions: [];

  // "center" (Clock/PowerStatus, both centred/right-anchored in Bar so the
  // panel opens straddling the box) or "left" (Workspaces — the leftmost
  // slot, so its panel opens flush with the box's own left edge and grows
  // rightward).
  property string panelAlign: "center";

  property Component panelContent: null;
  readonly property int panelWidth: panelLoader.item ? panelLoader.item.implicitWidth : 0;
  readonly property int panelHeight: panelLoader.item ? panelLoader.item.implicitHeight : 0;

  // Monitor height, forwarded from Bar so the panel content can cap itself to
  // the screen. Pushed onto the loaded item (if it wants it) via Binding below.
  property real panelScreenHeight: 0;

  // This bar's HyprlandMonitor, forwarded the same way — WorkspacesPanel needs
  // it to show the same bullets the collapsed box does.
  property var panelMonitor: null;

  property bool panelOpen: false;

  // Separately-timed grace period for panelOpen specifically, matching
  // panelLoader's own 160ms opacity fade below. Panel content reads this
  // (as panelActive, below) to keep doing panel-ish things — e.g.
  // SystemPanel's power-draw sampler — for exactly as long as it's still
  // visibly fading out, rather than resetting the instant panelOpen flips.
  // Not used for sizing (see implicitWidth/Height below) — that eases on
  // its own now and doesn't need a grace period to stay in sync with
  // anything.
  property bool panelClosing: false;

  // Pages that a global shortcut opens (LauncherService, AssistantService).
  // Emitted when the panel closes (by any route) while it was on one of them,
  // so Bar.qml can clear that service's `open` to match.
  readonly property var hotkeyApps: ["launcher", "assistant"];
  signal appDismissed(string appId);

  onPanelOpenChanged: {
    if (panelOpen) {
      panelCloseTimer.stop();
      panelClosing = false;
      // Land on the panel's home view every open, not wherever it was left.
      // Guarded so it's a no-op for panel content without that notion.
      if (panelLoader.item && "openApp" in panelLoader.item)
        panelLoader.item.openApp = "";
    } else {
      panelClosing = true;
      panelCloseTimer.restart();
      var app = panelLoader.item ? panelLoader.item.openApp : "";
      if (box.hotkeyApps.indexOf(app) >= 0)
        box.appDismissed(app);
    }
  }
  Timer { id: panelCloseTimer; interval: 160; onTriggered: box.panelClosing = false; }

  // Driven by Bar.qml from LauncherService / AssistantService — opens this
  // slot's panel straight onto that page (openApp === appId), morphing the
  // bar exactly like a drawer app. openApp() must set the page *after*
  // panelOpen, since onPanelOpenChanged resets it to "".
  function openApp(appId) {
    box.panelOpen = true;
    if (panelLoader.item && "openApp" in panelLoader.item)
      panelLoader.item.openApp = appId;
  }
  function closeApp(appId) {
    if (panelLoader.item && panelLoader.item.openApp === appId)
      box.panelOpen = false;
  }

  // box's own on-screen size is a live read of whatever is showing — the
  // content's geometry, or the panel's — and the one thing everything else
  // (the mask, BarSurface's shape in Bar.qml) reads, so they move together.
  //
  // Opening, closing and resizing an open panel run through split-axis
  // springs: growing widens first and deepens 40ms later, shrinking flattens
  // first and narrows 40ms later. Outside a panel morph the content's own
  // (already eased) hover size is read straight through.
  readonly property real _rawWidth: box.panelOpen ? box.panelWidth : (contentItem ? contentItem.width : 0);
  readonly property real _rawHeight: box.panelOpen ? box.panelHeight : (contentItem ? contentItem.height : 0);
  readonly property bool morphing: box.panelOpen || box.panelClosing || widthSpring.moving || heightSpring.moving;

  Spring {
    id: widthSpring;
    to: box._rawWidth;
    live: box.panelOpen || box.panelClosing;
    growPeriod: 0.50;
    shrinkPeriod: 0.40; shrinkDelay: 0.04;
  }
  Spring {
    id: heightSpring;
    to: box._rawHeight;
    live: box.panelOpen || box.panelClosing;
    growPeriod: 0.55; growDelay: 0.04;
    shrinkPeriod: 0.40;
  }

  implicitWidth: box.morphing ? widthSpring.value : box._rawWidth;
  implicitHeight: box.morphing ? heightSpring.value : box._rawHeight;

  // Clipped while the size is still catching up, so content already laid
  // out at its target size doesn't spill past the shape. Not clipped once
  // open and settled — WorkspacesPanel's drag ghost follows the cursor
  // outside its own bounds.
  clip: !box.panelOpen || widthSpring.moving || heightSpring.moving;

  Item {
    id: contentContainer;
    anchors.fill: parent;
    opacity: box.panelOpen ? 0 : 1;
    // Invisible (and so untappable, and excluded from the window's pointer
    // mask below) the moment the panel opens — that's what keeps a tap on a
    // panel control (e.g. a theme swatch) from also being seen as "tap the
    // pill", which used to immediately toggle the panel shut again.
    visible: opacity > 0;

    // Out quickly as the shape starts to grow; back in once it has mostly settled.
    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: box.panelOpen ? 0 : 150 }
        NumberAnimation { duration: box.panelOpen ? 100 : 250; easing.type: Easing.OutCubic }
      }
    }

    // Opens the panel. There's no matching "tap again to close" here on
    // purpose — closing is click-*outside*, handled by the scrim in
    // Bar.qml, and this item stops receiving taps at all once the panel is
    // open (visible: false above), so it can't fight that.
    TapHandler {
      acceptedButtons: Qt.LeftButton;
      onTapped: (eventPoint) => {
        if (box.contentSuppressesTap) return;
        var p = eventPoint.position;
        for (var i = 0; i < box.contentTapExclusions.length; i++) {
          var r = box.contentTapExclusions[i];
          if (p.x >= r.x && p.x <= r.x + r.width && p.y >= r.y && p.y <= r.y + r.height) return;
        }
        box.panelOpen = true;
      }
    }
  }

  Loader {
    id: panelLoader;
    anchors {
      top: parent.top;
      horizontalCenter: box.panelAlign === "center" ? parent.horizontalCenter : undefined;
      left: box.panelAlign === "left" ? parent.left : undefined;
    }
    active: box.panelContent !== null;
    sourceComponent: box.panelContent;
    opacity: box.panelOpen ? 1 : 0;
    visible: opacity > 0;

    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: box.panelOpen ? 150 : 0 }
        NumberAnimation { duration: box.panelOpen ? 220 : 90; easing.type: Easing.OutCubic }
      }
    }
  }

  Binding {
    target: panelLoader.item;
    property: "screenHeight";
    value: box.panelScreenHeight;
    when: panelLoader.item !== null && "screenHeight" in panelLoader.item;
  }

  Binding {
    target: panelLoader.item;
    property: "monitor";
    value: box.panelMonitor;
    when: panelLoader.item !== null && "monitor" in panelLoader.item;
  }

  Binding {
    target: panelLoader.item;
    property: "panelActive";
    value: box.panelOpen || box.panelClosing;
    when: panelLoader.item !== null && "panelActive" in panelLoader.item;
  }

  // Panel content can ask to close itself (e.g. WorkspacesPanel's header
  // up-chevron). Harmless no-op for panels without the signal.
  Connections {
    target: panelLoader.item;
    ignoreUnknownSignals: true;
    function onCloseRequested() { box.panelOpen = false; }
  }
}
