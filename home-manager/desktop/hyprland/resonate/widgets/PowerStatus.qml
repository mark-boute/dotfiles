import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray

import qs
import qs.services as Services

// Three states, in increasing size:
//   1. collapsed (default) — battery % only.
//   2. hovered — widens (width only, see the comment on `expanded` below)
//      to also show an expand chevron; nothing else changes.
//   3. expanded (clicked the chevron) — icon row: system tray, a divider,
//      then audio/wifi/bluetooth/power-draw/GPU-draw. Right-clicking a
//      tray icon with a menu swaps the row for that menu's items instead
//      (`activeMenuItem`/`showingMenu`).
// Leaving the pill (mouse-out) always resets back to state 1.
Rectangle {
  id: power;
  visible: UPower.displayDevice.isLaptopBattery;

  readonly property int collapsedSize: Theme.barHeight;
  readonly property int collapsedWidth: collapsedContent.implicitWidth + Theme.defaultMargin * 2;

  property bool manuallyExpanded: false;
  property var activeMenuItem: null;
  readonly property bool showingMenu: activeMenuItem !== null;

  // showingOsd folded in here (not just checked separately at the call
  // site) because this is also what Bar.qml reads, via CenterWidget's
  // contentExpanded/contentExpandedWidth/contentExpandedHeight, to size
  // the actual layer-shell window this pill draws inside — miss it here
  // and the window itself stays too small while the OSD is showing, so
  // the OSD gets hard-clipped at the old (smaller) surface edge. That
  // was live and reproducible: the widget rendered cut off during normal
  // use, but appeared correctly in a screenshot, because the OSD-driven
  // implicitWidth/Height on this Rectangle re-composited to the *actual*
  // (already-correct) content bounds within a surface that was still the
  // old size — screenshotting forced a fresh compositor pass that just
  // happened to catch that; nothing about the screenshot itself mattered.
  readonly property bool expanded: manuallyExpanded || showingMenu || showingOsd;
  readonly property alias hovered: hoverHandler.hovered;

  // Transient OSD: brightness/temperature/volume keybinds (hypr/keybinds.lua)
  // now go through Brightness/Temperature/AudioService's IPC handlers
  // instead of shelling out directly, so this pill can react to a
  // keybind-driven change the same way a phone/laptop OSD would, in
  // either collapsed or manually-expanded state — see osdContent below.
  // If more than one flashes at once (unlikely — the keybinds are all on
  // separate keys) this priority order wins arbitrarily rather than
  // trying to show more than one at a time.
  readonly property bool showingOsd: Services.BrightnessService.showOsd || Services.TemperatureService.showOsd || Services.AudioService.showOsd;
  readonly property string osdKind: Services.BrightnessService.showOsd ? "brightness"
    : Services.TemperatureService.showOsd ? "temperature" : "volume";
  readonly property real osdValue: {
    if (osdKind === "brightness") return Services.BrightnessService.brightness;
    if (osdKind === "temperature") {
      return (Services.TemperatureService.temperatureK - Services.TemperatureService.minTempK)
        / (Services.TemperatureService.maxTempK - Services.TemperatureService.minTempK);
    }
    return Services.AudioService.muted ? 0 : Services.AudioService.volume;
  }
  readonly property string osdGlyph: {
    if (osdKind === "brightness") return String.fromCodePoint(0xf05a8); // md-white_balance_sunny
    if (osdKind === "temperature") return String.fromCodePoint(0xf050f); // md-thermometer
    return Services.AudioService.iconGlyph;
  }
  readonly property string osdLabel: {
    if (osdKind === "temperature") return Services.TemperatureService.temperatureK + "K";
    if (osdKind === "volume") return Services.AudioService.muted ? "Muted" : Math.round(Services.AudioService.volume * 100) + "%";
    return Math.round(Services.BrightnessService.brightness * 100) + "%";
  }

  // The popup itself is a live control, not just a readout — dragging or
  // scrolling on it (see osdContent below) adjusts whichever value it's
  // currently showing, same as the matching slider in PowerPanel would.
  // Routed by osdKind rather than exposing three separate handlers on the
  // bar, since only one kind is ever showing at a time.
  function osdSetValue(fraction) {
    fraction = Math.max(0, Math.min(1, fraction));
    if (osdKind === "brightness") Services.BrightnessService.setBrightness(fraction);
    else if (osdKind === "temperature") Services.TemperatureService.setTemperature(fraction);
    else Services.AudioService.setVolume(fraction);
  }
  function osdStep(deltaFraction) {
    power.osdSetValue(power.osdValue + deltaFraction);
  }

  // No longer resets activeMenuItem (or anything else) on hover-out — a
  // menu closing on mouse-out used to race with opening it in the first
  // place: the container instantly snaps to the menu's full size (see the
  // right-anchored comment below) while this pill's own size Behavior-
  // animates smoothly, and during that brief mismatch the cursor could
  // end up outside this pill's still-catching-up hit region, firing a
  // spurious hover-out that nulled activeMenuItem the instant after it
  // was set — the menu would open and immediately close again. Making it
  // persist (closed only via its own explicit control, same as the icon
  // row) sidesteps the race entirely rather than trying to out-time it.

  readonly property int expandedWidth: showingOsd
    ? osdContent.implicitWidth + Theme.defaultMargin * 2
    : (showingMenu ? menuContent.implicitWidth : expandedContent.implicitWidth) + Theme.defaultMargin * 2;

  readonly property int expandedHeight: {
    if (showingOsd) return collapsedSize * 2;
    return showingMenu ? (menuContent.implicitHeight + Theme.defaultMargin * 2) : collapsedSize;
  }

  // Only the currently-showing row, not a union of all three — an
  // earlier version unioned every row's interactive children to dodge a
  // race where a state-changing tap (the chevron) could get checked
  // against the row it had just switched *to* rather than the one
  // actually clicked. But an inactive row's rects don't disappear just
  // because it's invisible, and they don't reliably avoid overlapping
  // the visible row's own empty space either — confirmed live, clicks in
  // clearly empty gaps of the expanded row were silently swallowed by an
  // unrelated collapsed/menu control's rect sitting on the same spot,
  // which is worse than the race it was working around. The chevron/
  // collapse/back controls that actually caused that race are now
  // covered by markControlActivated()/suppressNextTap instead (checked
  // unconditionally, before any geometry, in CenterWidget) and no longer
  // need to be in this list at all, so going back to "just the current
  // row" is safe again — see their tap handlers below.
  readonly property var controlsExclusions: {
    var source = showingMenu ? menuContent : (manuallyExpanded ? expandedContent : collapsedContent);
    var rects = [];
    for (var i = 0; i < source.children.length; i++) {
      var child = source.children[i];
      if (child.isInteractive === true) {
        var topLeft = child.mapToItem(power.parent, 0, 0);
        rects.push(Qt.rect(topLeft.x, topLeft.y, child.width, child.height));
      }
    }
    return rects;
  }

  property bool suppressNextTap: false;
  function markControlActivated() {
    suppressNextTap = true;
    Qt.callLater(() => suppressNextTap = false);
  }

  // Trivial now (just an alias for the direct assignment) — kept so both
  // call sites stay symmetrical and easy to extend later, and so there's
  // one obvious place to look if menu open/close ever needs more again.
  function openMenuFor(item) {
    activeMenuItem = item;
  }
  function closeMenu() {
    activeMenuItem = null;
  }

  // Left-click on a tray icon: focus that app's actual window (switching
  // to its workspace, which focusing a window elsewhere already does)
  // rather than relying on the SNI Activate() method, whose behavior is
  // entirely up to the app — some toggle minimize, some do nothing, so
  // it isn't a reliable stand-in. Looked up by matching the tray item's
  // id/title against `hyprctl clients` rather than building a class-name
  // regex directly, since SNI id/title casing doesn't reliably match a
  // window's real WM_CLASS. Dispatched via `hl.dsp.focus({ window = ... })`
  // — this Hyprland config runs its own Lua dispatcher shim (see
  // hypr/keybinds.lua), so the standard `hyprctl dispatch focuswindow
  // address:...` form errors out; NotificationService.qml already
  // established the working call shape for a window-selector focus.
  property var pendingFocusItem: null;
  Process {
    id: clientListProc;
    command: ["hyprctl", "clients", "-j"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        var item = power.pendingFocusItem;
        power.pendingFocusItem = null;
        if (!item) return;
        var query = ((item.id || item.title || "")).toLowerCase();
        if (!query) { item.activate(); return; }
        var clients = [];
        try { clients = JSON.parse(t || "[]"); } catch (e) { clients = []; }
        // Checked both directions: an SNI id can be *longer* than the
        // window's actual class (confirmed live — Spotify's tray item
        // reports id "spotify-client" against a plain "spotify" class,
        // so `class.includes(query)` alone never matched; only the
        // reverse, `query.includes(class)`, does).
        var match = clients.find(c => {
          var cls = (c.class || "").toLowerCase();
          var ttl = (c.title || "").toLowerCase();
          return (cls && (query.includes(cls) || cls.includes(query))) ||
                 (ttl && (query.includes(ttl) || ttl.includes(query)));
        });
        if (match) {
          focusWindowProc.command = ["hyprctl", "dispatch",
            "hl.dsp.focus({ window = \"address:" + match.address + "\" })"];
          focusWindowProc.running = true;
        } else {
          item.activate();
        }
      }
    }
  }
  Process { id: focusWindowProc; }
  function focusApp(item) {
    pendingFocusItem = item;
    clientListProc.running = true;
  }

  anchors { top: parent.top; right: parent.right; }

  // Bottom-rounded "notch" hanging from the bar's connecting strip
  // (Bar.qml) — no border (would draw a seam right where this meets the
  // strip). Square top corners via per-corner radius, not a same-color
  // Rectangle painted over the top to flatten it — that approach stacked
  // two translucent layers of CurrentTheme.surface in the top band,
  // compositing visibly darker there than the single-layer rest of the
  // pill (confirmed live: a sharp horizontal color seam right at the
  // patch's own edge).
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

  // Smooths the concave seam where this island's left edge meets the
  // connecting strip above (see NotchFillet.qml) — a child of this
  // Rectangle, positioned off its own width/height, so it stays in
  // lockstep with this island's own size changes. Only on the left: this
  // is the rightmost island, flush with the strip's own right edge, so
  // there's no seam to smooth on the right.
  NotchFillet {
    id: leftFillet;
    x: -leftFillet.filletRadius;
    y: Theme.barConnectorHeight;
  }

  // expanded/expandedWidth/expandedHeight above already fold in the OSD
  // case (see the comment on `expanded`), so this needs no separate
  // branch for it.
  implicitWidth: expanded ? expandedWidth : collapsedWidth;
  implicitHeight: expanded ? expandedHeight : collapsedSize;

  Behavior on implicitWidth  { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
  Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
  Behavior on color          { ColorAnimation  { duration: 180 } }

  readonly property color levelColor: {
    if (UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return CurrentTheme.success;
    if (UPower.displayDevice.state === UPowerDeviceState.Charging) return CurrentTheme.accent;
    if (UPower.displayDevice.percentage <= 0.2) return CurrentTheme.danger;
    if (UPower.displayDevice.percentage <= 0.4) return CurrentTheme.warning;
    return CurrentTheme.success;
  }

  readonly property string stateGlyph: {
    if (UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return "✓ "; // check
    if (UPower.displayDevice.state === UPowerDeviceState.Charging) return "⚡ ";     // bolt
    return "";
  }

  Row {
    id: collapsedContent;
    anchors.centerIn: parent;
    spacing: 5;
    // expanded, not manuallyExpanded: a menu opened directly from the
    // collapsed row (right-clicking a tray icon there, without ever
    // clicking the chevron first) sets showingMenu without ever setting
    // manuallyExpanded — this used to stay at opacity 1 in that case,
    // rendering on top of menuContent since both were visible at once.
    // expanded folds in showingOsd the same way (see its own comment).
    opacity: power.expanded ? 0 : 1;
    visible: opacity > 0;

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Repeater {
      model: SystemTray.items;

      Item {
        id: trayIconSlot;
        required property var modelData;
        // controlsExclusions only inspects *direct* row children — this
        // wrapper, not the TrayIcon nested inside it, is what that scan
        // actually sees. TrayIcon's own isInteractive:true lives one
        // level too deep to matter here, which is why tray icons were
        // never actually excluded: left-clicking one correctly fired its
        // own tap handler, but the click also fell through to
        // CenterWidget's ancestor handler and opened the command center
        // every time, since nothing here was ever telling it not to.
        readonly property bool isInteractive: true;
        anchors.verticalCenter: parent.verticalCenter;
        implicitWidth: Theme.iconSize;
        implicitHeight: Theme.iconSize;
        width: implicitWidth;
        height: implicitHeight;

        TrayIcon {
          anchors.fill: parent;
          trayItem: trayIconSlot.modelData;
          owner: power;
        }
      }
    }

    // A Row's own `spacing` is uniform between every child, but this
    // divider wants more clearance than the tight inter-icon spacing
    // above — defaultMargin (14) read as "too much"; defaultSpacing (8)
    // instead. Wrapped in a box wide enough that the visible 1px line,
    // centered within it, ends up with (defaultSpacing - spacing) of
    // extra clearance on each side — added to the row's own spacing,
    // that totals defaultSpacing either way. Math.max keeps this from
    // going negative if a row's own spacing ever exceeds the target
    // (which would mean "no extra needed", not "negative padding").
    Item {
      visible: SystemTray.items.values.length > 0;
      anchors.verticalCenter: parent.verticalCenter;
      implicitWidth: 1 + Math.max(0, Theme.defaultSpacing - collapsedContent.spacing) * 2;
      implicitHeight: 16;
      width: implicitWidth;
      height: implicitHeight;

      Rectangle {
        anchors.centerIn: parent;
        width: 1;
        height: parent.height;
        color: CurrentTheme.border;
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter;
      text: power.stateGlyph + Math.floor(UPower.displayDevice.percentage * 100) + "%";
      color: power.levelColor;
      font.pixelSize: 14;
      font.weight: Font.DemiBold;
    }

    // No isInteractive here — this control changes manuallyExpanded, so
    // geometric exclusion for it specifically is unreliable (see
    // controlsExclusions above); markControlActivated() in its own
    // TapHandler already covers it unconditionally, before any geometry.
    Item {
      visible: power.hovered;
      anchors.verticalCenter: parent.verticalCenter;
      implicitWidth: chevronGlyph.implicitWidth + 12;
      implicitHeight: power.collapsedSize;
      width: implicitWidth;
      height: implicitHeight;

      Text {
        id: chevronGlyph;
        anchors.centerIn: parent;
        text: String.fromCodePoint(0xf0140); // md-chevron_down
        font.family: Theme.iconFontFamily;
        font.pixelSize: Theme.iconSize;
        color: CurrentTheme.subtext;
      }

      TapHandler {
        onTapped: { power.markControlActivated(); power.manuallyExpanded = true; }
      }
    }
  }

  // Icon + thin fill bar + value label, styled after the battery bar at
  // the top of PowerPanel.qml — flashed by Brightness/Temperature/
  // AudioService whenever their value changes (a keybind, this panel's
  // own sliders, or the bar below directly), then auto-hidden again by
  // their own osdTimer. Sized noticeably larger than the row it replaces
  // (wider in particular) so it reads as a deliberate OSD popup, not
  // just another cramped bar control.
  Row {
    id: osdContent;
    anchors.centerIn: parent;
    spacing: 12;
    visible: power.showingOsd;
    opacity: visible ? 1 : 0;

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Text {
      anchors.verticalCenter: parent.verticalCenter;
      text: power.osdGlyph;
      font.family: Theme.iconFontFamily;
      font.pixelSize: Theme.iconSize + 8;
      color: CurrentTheme.text;
    }

    // Live control, not just a readout — drag or scroll to adjust
    // whichever value the popup is currently showing. Same TapHandler +
    // DragHandler + wheel-only-MouseArea shape as SliderPill.qml (a bare
    // WheelHandler was found not to fire in this setup).
    Rectangle {
      id: osdBarTrack;
      anchors.verticalCenter: parent.verticalCenter;
      width: 180;
      height: 12;
      radius: height / 2;
      color: CurrentTheme.background;

      Rectangle {
        width: parent.width * power.osdValue;
        height: parent.height;
        radius: parent.radius;
        color: CurrentTheme.accent;

        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      }

      // markControlActivated() on every interaction here — same reasoning
      // as the chevron/menu controls above: this pill sits inside
      // CenterWidget's own "tap anywhere opens the command panel"
      // handler, and geometric exclusion (controlsExclusions) doesn't
      // cover the popup row at all, so without this a drag/tap here
      // would also pop the full panel open behind it.
      TapHandler {
        onTapped: (eventPoint) => {
          power.markControlActivated();
          power.osdSetValue(eventPoint.position.x / osdBarTrack.width);
        }
      }

      DragHandler {
        target: null;
        onCentroidChanged: {
          if (!active) return;
          power.markControlActivated();
          power.osdSetValue(centroid.position.x / osdBarTrack.width);
        }
      }

      MouseArea {
        anchors.fill: parent;
        acceptedButtons: Qt.NoButton;
        onWheel: (wheel) => {
          power.markControlActivated();
          power.osdStep(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
        }
      }
    }

    Text {
      id: osdLabelWidthRef;
      visible: false;
      text: "100%";
      font.pixelSize: 15;
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter;
      text: power.osdLabel;
      color: CurrentTheme.subtext;
      font.pixelSize: 15;
      horizontalAlignment: Text.AlignRight;
      width: Math.max(implicitWidth, osdLabelWidthRef.implicitWidth);
    }
  }

  readonly property real powerDraw: Math.abs(UPower.displayDevice.changeRate);

  property real gpuWatts: 0;
  property bool gpuAsleep: true;
  Process {
    id: gpuPowerProc;
    command: ["sh", "-c",
      "s=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null); " +
      "[ \"$s\" = D3cold ] && { echo asleep; exit; }; " +
      "ls -l /proc/[0-9]*/fd 2>/dev/null | grep -q /dev/nvidia0 " +
      "&& nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits || echo asleep"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        t = (t || "").trim();
        if (t === "asleep" || t === "") {
          power.gpuAsleep = true;
          power.gpuWatts = 0;
        } else {
          power.gpuAsleep = false;
          power.gpuWatts = parseFloat(t) || 0;
        }
      }
    }
  }

  Timer {
    interval: 2000;
    repeat: true;
    triggeredOnStart: true;
    running: power.manuallyExpanded && !power.showingMenu;
    onTriggered: gpuPowerProc.running = true;
  }

  Row {
    id: expandedContent;
    anchors.centerIn: parent;
    spacing: 10;
    visible: power.manuallyExpanded && !power.showingMenu && !power.showingOsd;
    opacity: visible ? 1 : 0;

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Repeater {
      model: SystemTray.items;

      // Not TrayIcon directly as the delegate: Repeater's injected
      // `modelData` context property didn't resolve correctly through a
      // required property on a separately-defined component (it was
      // picking up Bar.qml's PanelWindow's own unrelated `modelData`,
      // the screen, instead — confirmed live, calling secondaryActivate()
      // on it threw "not a function" on a QuickshellScreenInfo). A plain
      // Item owning `modelData` directly, matching how every other
      // Repeater delegate in this codebase does it, sidesteps whatever
      // that resolution issue was.
      Item {
        id: trayIconSlot;
        required property var modelData;
        // controlsExclusions only inspects *direct* row children — this
        // wrapper, not the TrayIcon nested inside it, is what that scan
        // actually sees. TrayIcon's own isInteractive:true lives one
        // level too deep to matter here, which is why tray icons were
        // never actually excluded: left-clicking one correctly fired its
        // own tap handler, but the click also fell through to
        // CenterWidget's ancestor handler and opened the command center
        // every time, since nothing here was ever telling it not to.
        readonly property bool isInteractive: true;
        anchors.verticalCenter: parent.verticalCenter;
        implicitWidth: Theme.iconSize;
        implicitHeight: Theme.iconSize;
        width: implicitWidth;
        height: implicitHeight;

        TrayIcon {
          anchors.fill: parent;
          trayItem: trayIconSlot.modelData;
          owner: power;
        }
      }
    }

    // See collapsedContent's own divider for why this is wrapped rather
    // than a bare Rectangle, and for defaultSpacing/Math.max — same
    // reasoning applies here.
    Item {
      visible: SystemTray.items.values.length > 0;
      anchors.verticalCenter: parent.verticalCenter;
      implicitWidth: 1 + Math.max(0, Theme.defaultSpacing - expandedContent.spacing) * 2;
      implicitHeight: Theme.iconSize;
      width: implicitWidth;
      height: implicitHeight;

      Rectangle {
        anchors.centerIn: parent;
        width: 1;
        height: parent.height;
        color: CurrentTheme.border;
      }
    }

    Text {
      readonly property bool isInteractive: true;
      anchors.verticalCenter: parent.verticalCenter;
      text: Services.AudioService.iconGlyph;
      font.family: Theme.iconFontFamily;
      font.pixelSize: Theme.iconSize;
      color: Services.AudioService.muted ? CurrentTheme.danger : CurrentTheme.text;

      TapHandler {
        onTapped: Services.AudioService.toggleMute();
      }
    }

    Text {
      readonly property bool isInteractive: true;
      anchors.verticalCenter: parent.verticalCenter;
      text: String.fromCodePoint(0xf05a9); // md-wifi
      font.family: Theme.iconFontFamily;
      font.pixelSize: Theme.iconSize;
      color: Services.NetworkService.enabled ? CurrentTheme.text : CurrentTheme.subtext;

      TapHandler {
        onTapped: Services.NetworkService.toggle();
      }
    }

    Text {
      readonly property bool isInteractive: true;
      anchors.verticalCenter: parent.verticalCenter;
      text: String.fromCodePoint(0xf00af); // md-bluetooth
      font.family: Theme.iconFontFamily;
      font.pixelSize: Theme.iconSize;
      color: Services.BluetoothService.enabled ? CurrentTheme.text : CurrentTheme.subtext;

      TapHandler {
        onTapped: Services.BluetoothService.toggle();
      }
    }

    Text {
      id: wattageWidthRef;
      visible: false;
      text: "88.8W";
      font.pixelSize: 12;
    }

    Row {
      anchors.verticalCenter: parent.verticalCenter;
      spacing: 3;

      Text {
        text: "⚡";
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
      }
      Text {
        text: power.powerDraw.toFixed(1) + "W";
        color: CurrentTheme.subtext;
        font.pixelSize: 12;
        horizontalAlignment: Text.AlignLeft;
        width: wattageWidthRef.implicitWidth;
      }
    }

    Row {
      anchors.verticalCenter: parent.verticalCenter;
      spacing: 3;
      visible: !power.gpuAsleep;

      Text {
        text: "GPU";
        color: CurrentTheme.warning;
        font.pixelSize: 11;
      }
      Text {
        text: power.gpuWatts.toFixed(1) + "W";
        color: CurrentTheme.warning;
        font.pixelSize: 12;
        horizontalAlignment: Text.AlignLeft;
        width: wattageWidthRef.implicitWidth;
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter;
      text: power.stateGlyph + Math.floor(UPower.displayDevice.percentage * 100) + "%";
      color: power.levelColor;
      font.pixelSize: 14;
      font.weight: Font.DemiBold;
    }

    // No isInteractive here either — same reasoning as the expand
    // chevron in collapsedContent above.
    Item {
      anchors.verticalCenter: parent.verticalCenter;
      implicitWidth: collapseGlyph.implicitWidth + 12;
      implicitHeight: power.collapsedSize;
      width: implicitWidth;
      height: implicitHeight;

      Text {
        id: collapseGlyph;
        anchors.centerIn: parent;
        text: String.fromCodePoint(0xf0143); // md-chevron_up
        font.family: Theme.iconFontFamily;
        font.pixelSize: Theme.iconSize;
        color: CurrentTheme.subtext;
      }

      TapHandler {
        onTapped: { power.markControlActivated(); power.manuallyExpanded = false; }
      }
    }
  }

  QsMenuOpener {
    id: menuOpener;
    // Just the one `.menu` (the item's DBusMenuHandle itself), not
    // `.menu.menu` — cappuccino's own working tray (Systemtray.qml /
    // MenuView.qml) assigns menuHandle straight from `modelData.menu`,
    // and menus here came up empty until matching that; drilling one
    // level further apparently handed QsMenuOpener something it
    // couldn't actually use.
    menu: (power.activeMenuItem && power.activeMenuItem.menu) || null;
  }

  Column {
    id: menuContent;
    anchors.centerIn: parent;
    spacing: 2;
    visible: power.showingMenu && !power.showingOsd;
    opacity: visible ? 1 : 0;

    Behavior on opacity { NumberAnimation { duration: 140 } }

    // Explicit close control — this menu stays open once opened (see the
    // comment on hovered above), so it needs its own way back too. Only
    // clears activeMenuItem, not manuallyExpanded, so it returns to
    // whichever state (icon row or collapsed) was showing before the
    // menu was opened, rather than forcing a full collapse. No
    // isInteractive — same reasoning as the expand/collapse chevrons.
    Item {
      implicitWidth: 170;
      implicitHeight: Math.max(backGlyph.implicitHeight, Theme.iconSize) + 4;
      width: implicitWidth;
      height: implicitHeight;

      Text {
        id: backGlyph;
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4; }
        text: String.fromCodePoint(0xf0141) + " Back"; // md-chevron_left
        font.family: Theme.iconFontFamily;
        font.pixelSize: 12;
        color: CurrentTheme.subtext;
      }

      // Which app's menu this is, so it stays legible after switching
      // straight from one tray item's menu to another.
      IconImage {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4; }
        implicitSize: Theme.iconSize;
        source: {
          var item = power.activeMenuItem;
          if (!item || !item.icon) return "";
          if (item.icon.includes("?path=")) {
            var parts = item.icon.split("?path=");
            var name = parts[0];
            var path = parts[1];
            return Qt.resolvedUrl(path + "/" + name.slice(name.lastIndexOf("/") + 1));
          }
          return item.icon;
        }
      }

      TapHandler {
        onTapped: { power.markControlActivated(); power.closeMenu(); }
      }
    }

    Repeater {
      model: menuOpener.children;

      Item {
        id: menuEntry;
        required property var modelData;
        
        readonly property bool isInteractive: !modelData.isSeparator;

        implicitWidth: 170;
        implicitHeight: modelData.isSeparator ? 9 : 24;
        width: implicitWidth;
        height: implicitHeight;

        Rectangle {
          visible: menuEntry.modelData.isSeparator;
          anchors.centerIn: parent;
          width: parent.width;
          height: 1;
          color: CurrentTheme.border;
        }

        Text {
          visible: !menuEntry.modelData.isSeparator;
          anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4; right: parent.right; rightMargin: 4; }
          text: menuEntry.modelData.text;
          elide: Text.ElideRight;
          color: menuEntry.modelData.enabled ? CurrentTheme.text : CurrentTheme.subtext;
          font.pixelSize: 12;
        }

        TapHandler {
          enabled: !menuEntry.modelData.isSeparator && menuEntry.modelData.enabled;
          onTapped: {
            power.markControlActivated();
            menuEntry.modelData.triggered(); // matches cappuccino's MenuItem.qml
            power.closeMenu();
            power.manuallyExpanded = false;
          }
        }
      }
    }
  }

  HoverHandler {
    id: hoverHandler;
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad;
  }
}
