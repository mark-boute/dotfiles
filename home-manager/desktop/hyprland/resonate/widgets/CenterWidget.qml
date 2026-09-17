import QtQuick

import qs

// A generic, auto-sizing holder for the bar's centerpiece. It doesn't know
// or care what `content` actually is (Clock today; a notification card or a
// volume slider later) beyond a small declared-size contract: collapsedSize,
// contentExpandedWidth/Height, and contentExpanded (whether that content is
// currently in its own bigger, e.g. hover, state). Clicking anywhere on it
// swaps to `panelContent` instead — the command center.
//
// Bar.qml reads collapsedSize/targetHeight/windowExpanded off this instance
// to size the actual panel window — see Bar.qml for why the window itself
// only resizes in discrete jumps rather than tracking continuously.
Item {
  id: holder;

  default property alias content: contentContainer.data;

  // collapsedSize is a *height* — the fixed square footprint used for the
  // bar's exclusiveZone. It is NOT the idle width: content is rarely
  // square (e.g. "21:04" or "✓ 100%" text), so the idle width comes from
  // contentCollapsedWidth instead, measured by the content itself.
  property int collapsedSize: 0;
  property int contentCollapsedWidth: 0;
  property int contentExpandedWidth: 0;
  property int contentExpandedHeight: 0;
  property bool contentExpanded: false;

  // When content wants a tap to do something itself (e.g. Clock invoking a
  // notification's action) instead of opening the command center — for
  // when the *entire* pill should behave that way right now.
  property bool contentSuppressesTap: false;

  // For when only specific sub-regions of the pill should behave that way —
  // e.g. PowerStatus's own icon row, where each icon (mute, wifi, a tray
  // item, ...) needs to do its own thing on tap rather than also opening
  // the panel. A list rather than a single rect since the icon count
  // varies (system tray). Content-local coordinates (same origin as
  // contentContainer below).
  property var contentTapExclusions: [];

  // "center" (Clock/PowerStatus, both centred/right-anchored in Bar so the
  // panel opens straddling the pill) or "left" (Workspaces — the leftmost
  // island, so its panel opens flush with the pill's own left edge and
  // grows rightward).
  property string panelAlign: "center";

  property Component panelContent: null;
  readonly property int panelWidth: panelLoader.item ? panelLoader.item.implicitWidth : 0;
  readonly property int panelHeight: panelLoader.item ? panelLoader.item.implicitHeight : 0;

  // Monitor height, forwarded from Bar so the panel content can cap itself to
  // the screen. Pushed onto the loaded item (if it wants it) via Binding below.
  property real panelScreenHeight: 0;

  // This bar's HyprlandMonitor, forwarded the same way — WorkspacesPanel needs
  // it to show the same bullets the collapsed island does.
  property var panelMonitor: null;

  property bool panelOpen: false;

  readonly property bool big: panelOpen || contentExpanded;

  // Debounced so the window (see targetWidth/targetHeight below) only ever
  // jumps in size once at the start of a hover/panel-open, and once again
  // after things have visually settled back down — never mid-animation.
  property bool windowExpanded: false;
  onBigChanged: {
    if (big) {
      settleTimer.stop();
      windowExpanded = true;
    } else {
      settleTimer.restart();
    }
  }
  Timer { id: settleTimer; interval: 180; onTriggered: holder.windowExpanded = false; }

  // Separately-timed grace period for panelOpen specifically, matching
  // panelLoader's own 160ms opacity fade below. Without this, targetWidth/
  // Height fell back to windowExpanded/collapsed sizing the instant
  // panelOpen went false — the wrapper (and everything sized off it: the
  // window, the connecting-strip gap segments, the mask) snapped back to
  // the pill's footprint immediately, while the panel itself was still
  // rendering at full size for another 160ms, fading out. That orphaned
  // the still-visible panel from the strip/window that had already
  // retracted out from under it — confirmed live, reproducible every
  // close. panelClosing keeps targetWidth/Height on panelWidth/Height
  // for exactly as long as the panel is still visible.
  property bool panelClosing: false;

  // Emitted when the panel closes (by any route) while it was on the launcher
  // page, so Bar.qml can clear LauncherService.open to match.
  signal launcherDismissed();

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
      if (panelLoader.item && panelLoader.item.openApp === "launcher")
        holder.launcherDismissed();
    }
  }
  Timer { id: panelCloseTimer; interval: 160; onTriggered: holder.panelClosing = false; }

  // Driven by Bar.qml from LauncherService — opens this island's panel
  // straight onto the launcher page (openApp === "launcher"), morphing the
  // notch exactly like a drawer app. openLauncher() must set openApp *after*
  // panelOpen, since onPanelOpenChanged resets it to "".
  function openLauncher() {
    holder.panelOpen = true;
    if (panelLoader.item && "openApp" in panelLoader.item)
      panelLoader.item.openApp = "launcher";
  }
  function closeLauncher() {
    if (panelLoader.item && panelLoader.item.openApp === "launcher")
      holder.panelOpen = false;
  }

  readonly property int targetWidth: (panelOpen || panelClosing)
    ? holder.panelWidth
    : (windowExpanded ? contentExpandedWidth : contentCollapsedWidth);
  readonly property int targetHeight: (panelOpen || panelClosing)
    ? holder.panelHeight
    : (windowExpanded ? contentExpandedHeight : collapsedSize);

  implicitWidth: targetWidth;
  implicitHeight: targetHeight;

  Item {
    id: contentContainer;
    anchors.fill: parent;
    opacity: holder.panelOpen ? 0 : 1;
    // Invisible (and so untappable, and excluded from the window's pointer
    // mask below) the moment the panel opens — that's what keeps a tap on a
    // panel control (e.g. a theme swatch) from also being seen as "tap the
    // pill", which used to immediately toggle the panel shut again.
    visible: opacity > 0;

    Behavior on opacity { NumberAnimation { duration: 120 } }

    // Opens the panel. There's no matching "tap again to close" here on
    // purpose — closing is click-*outside*, handled by the scrim in
    // Bar.qml, and this item stops receiving taps at all once the panel is
    // open (visible: false above), so it can't fight that.
    TapHandler {
      acceptedButtons: Qt.LeftButton;
      onTapped: (eventPoint) => {
        if (holder.contentSuppressesTap) return;
        var p = eventPoint.position;
        for (var i = 0; i < holder.contentTapExclusions.length; i++) {
          var r = holder.contentTapExclusions[i];
          if (p.x >= r.x && p.x <= r.x + r.width && p.y >= r.y && p.y <= r.y + r.height) return;
        }
        holder.panelOpen = true;
      }
    }
  }

  Loader {
    id: panelLoader;
    anchors {
      top: parent.top;
      horizontalCenter: holder.panelAlign === "center" ? parent.horizontalCenter : undefined;
      left: holder.panelAlign === "left" ? parent.left : undefined;
    }
    active: holder.panelContent !== null;
    sourceComponent: holder.panelContent;
    opacity: holder.panelOpen ? 1 : 0;
    visible: opacity > 0;

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
  }

  Binding {
    target: panelLoader.item;
    property: "screenHeight";
    value: holder.panelScreenHeight;
    when: panelLoader.item !== null && "screenHeight" in panelLoader.item;
  }

  Binding {
    target: panelLoader.item;
    property: "monitor";
    value: holder.panelMonitor;
    when: panelLoader.item !== null && "monitor" in panelLoader.item;
  }

  Binding {
    target: panelLoader.item;
    property: "panelActive";
    value: holder.panelOpen || holder.panelClosing;
    when: panelLoader.item !== null && "panelActive" in panelLoader.item;
  }

  // Panel content can ask to close itself (e.g. WorkspacesPanel's header
  // up-chevron). Harmless no-op for panels without the signal.
  Connections {
    target: panelLoader.item;
    ignoreUnknownSignals: true;
    function onCloseRequested() { holder.panelOpen = false; }
  }
}
