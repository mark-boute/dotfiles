import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

import qs
import qs.services as Services

// Collapsed: a small pill showing just "HH:MM" — collapsedSize is the bar's
// true height (read by CenterWidget/Bar.qml for the exclusiveZone).
//
// "Big" (expanded) state shows one of three things, in priority order:
//   1. notification — a fresh notification just arrived (see
//      NotificationService.latestNotification); shows unprompted, no hover
//      needed, and reverts to the clock on its own after a few seconds.
//   2. media — hovering, and Spotify (specifically) is active; play/pause
//      + prev/next controls.
//   3. date — hovering, nothing more interesting going on; weekday + date.
//
// This only concerns itself with its own idle/big visuals; sizing them into
// an actual window and handling clicks (-> command center) is
// CenterWidget's job, which reads collapsedSize/expandedWidth/expandedHeight
// /expanded off this item.
Rectangle {
  id: clock;

  readonly property bool hasNotification: Services.NotificationService.latestNotification !== null;
  readonly property bool hasMedia: Services.MediaService.hasPlayer;
  readonly property bool hovered: hoverHandler.hovered;

  readonly property string bigMode: hasNotification ? "notification" : (hasMedia ? "media" : "date");

  readonly property int collapsedSize: Theme.barHeight;
  readonly property int collapsedWidth: collapsedContent.implicitWidth + Theme.defaultMargin * 2;
  readonly property bool expanded: hasNotification || hovered;

  // Read by CenterWidget: while a notification is showing, a tap should
  // invoke it (see TapHandler below), not open the command center.
  readonly property bool suppressPanelOpen: hasNotification;

  // Holds the spotlight open indefinitely while genuinely looking at it —
  // see NotificationService.spotlightHeld.
  Binding {
    target: Services.NotificationService;
    property: "spotlightHeld";
    value: clock.hasNotification && clock.hovered;
  }

  readonly property int expandedWidth: {
    // notificationContent is left-aligned with a fixed content width and
    // dedicated clearance on the right for the close button, rather than
    // centered like the other two — so it's sized directly, not via
    // implicitWidth + symmetric margins the way media/date are.
    if (bigMode === "notification") return Theme.defaultMargin + notificationContent.width + 26;
    var w = bigMode === "media" ? mediaContent.implicitWidth : dateContent.implicitWidth;
    return Math.max(collapsedContent.implicitWidth, w) + Theme.defaultMargin * 2;
  }
  readonly property int expandedHeight: {
    var h = bigMode === "notification" ? notificationContent.implicitHeight
          : bigMode === "media" ? mediaContent.implicitHeight
          : dateContent.implicitHeight;
    return h + Theme.defaultMargin * 2;
  }

  // Top edge + horizontal center only (not centerIn) — those two points
  // never move as this Rectangle's own size animates, so the grow/shrink
  // reads as this pill morphing outward in place, not repositioning first.
  anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; }

  // Not `expanded ? 16 : height / 2` — that flips instantly the moment
  // expanded toggles, while height is still mid-Behavior-animation, so
  // radius ends up chasing a continuously-moving target and lags behind
  // where height actually is, producing squared-off corners mid-animation
  // (very visible now that the drop shadow outlines the exact silhouette).
  // Deriving radius directly from height needs no Behavior of its own —
  // it's already smooth because height already is.
  radius: Math.min(16, height / 2);
  color: CurrentTheme.surface;
  border.width: 1;
  border.color: hasNotification ? CurrentTheme.accent : CurrentTheme.border;

  layer.enabled: true;
  layer.effect: MultiEffect {
    shadowEnabled: true;
    shadowColor: Theme.shadowColor;
    shadowBlur: Theme.shadowBlur;
    shadowVerticalOffset: Theme.shadowVerticalOffset;
  }

  implicitWidth: expanded ? expandedWidth : collapsedWidth;
  implicitHeight: expanded ? expandedHeight : collapsedSize;

  Behavior on implicitWidth  { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
  Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
  Behavior on color          { ColorAnimation  { duration: 180 } }
  Behavior on border.color   { ColorAnimation  { duration: 180 } }

  Text {
    id: collapsedContent;
    anchors.centerIn: parent;
    opacity: clock.expanded ? 0 : 1;
    text: Services.SystemClock.time;
    color: CurrentTheme.accent;
    font.pixelSize: 14;
    font.weight: Font.DemiBold;

    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  Column {
    id: notificationContent;
    // Left-aligned (not centered) with dedicated clearance on the right for
    // the close button, like a normal toast card rather than a centered one.
    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.defaultMargin; }
    spacing: 3;
    width: 200;
    opacity: clock.expanded && clock.bigMode === "notification" ? 1 : 0;
    visible: opacity > 0;

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    readonly property var n: Services.NotificationService.latestNotification;

    Row {
      spacing: 6;
      anchors.left: parent.left;

      IconImage {
        anchors.verticalCenter: parent.verticalCenter;
        implicitSize: 14;
        visible: source.toString() !== "";
        source: {
          var n = notificationContent.n;
          if (!n) return "";
          if (n.image) return n.image;
          var ic = n.appIcon;
          if (!ic) return "";
          return (ic.startsWith("/") || ic.indexOf("://") !== -1) ? ic : Quickshell.iconPath(ic, true);
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter;
        text: notificationContent.n ? notificationContent.n.appName : "";
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
      }
    }

    Text {
      width: parent.width;
      text: notificationContent.n ? notificationContent.n.summary : "";
      color: CurrentTheme.text;
      font.pixelSize: 13;
      font.weight: Font.DemiBold;
      elide: Text.ElideRight;
    }

    Text {
      width: parent.width;
      visible: notificationContent.n && notificationContent.n.body !== "";
      text: notificationContent.n ? notificationContent.n.body : "";
      color: CurrentTheme.subtext;
      font.pixelSize: 11;
      wrapMode: Text.WordWrap;
      maximumLineCount: 2;
      elide: Text.ElideRight;
    }
  }

  // Top-right dismiss — ported from cappuccino's NotificationOverlay.qml.
  Rectangle {
    id: closeBtn;
    visible: clock.expanded && clock.bigMode === "notification";
    width: 18;
    height: 18;
    radius: 9;
    anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 6; }
    color: closeHover.hovered ? CurrentTheme.surfaceHover : "transparent";

    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      anchors.centerIn: parent;
      text: "×";
      color: CurrentTheme.subtext;
      font.pixelSize: 13;
    }

    HoverHandler { id: closeHover; }

    TapHandler {
      acceptedButtons: Qt.LeftButton;
      onTapped: {
        var n = Services.NotificationService.latestNotification;
        if (n) Services.NotificationService.dismiss(n);
      }
    }
  }

  Column {
    id: mediaContent;
    anchors.centerIn: parent;
    spacing: 6;
    opacity: clock.expanded && clock.bigMode === "media" ? 1 : 0;
    visible: opacity > 0;

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter;
      width: 180;
      horizontalAlignment: Text.AlignHCenter;
      text: Services.MediaService.title;
      color: CurrentTheme.text;
      font.pixelSize: 13;
      font.weight: Font.DemiBold;
      elide: Text.ElideRight;
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter;
      width: 180;
      horizontalAlignment: Text.AlignHCenter;
      text: Services.MediaService.artist;
      color: CurrentTheme.subtext;
      font.pixelSize: 11;
      elide: Text.ElideRight;
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter;
      spacing: 16;

      Text {
        text: "⏮";
        color: Services.MediaService.canGoPrevious ? CurrentTheme.text : CurrentTheme.subtext;
        font.pixelSize: 14;
        TapHandler { enabled: Services.MediaService.canGoPrevious; onTapped: Services.MediaService.previous(); }
      }

      Text {
        text: Services.MediaService.playing ? "⏸" : "▶";
        color: CurrentTheme.accent;
        font.pixelSize: 16;
        TapHandler { onTapped: Services.MediaService.togglePlaying(); }
      }

      Text {
        text: "⏭";
        color: Services.MediaService.canGoNext ? CurrentTheme.text : CurrentTheme.subtext;
        font.pixelSize: 14;
        TapHandler { enabled: Services.MediaService.canGoNext; onTapped: Services.MediaService.next(); }
      }
    }
  }

  Column {
    id: dateContent;
    anchors.centerIn: parent;
    spacing: 2;
    opacity: clock.expanded && clock.bigMode === "date" ? 1 : 0;
    visible: opacity > 0;

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter;
      text: Services.SystemClock.weekday;
      color: CurrentTheme.subtext;
      font.pixelSize: 12;
      font.weight: Font.Medium;
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter;
      text: Services.SystemClock.time;
      color: CurrentTheme.accent;
      font.pixelSize: 26;
      font.weight: Font.Bold;
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter;
      text: Services.SystemClock.date;
      color: CurrentTheme.subtext;
      font.pixelSize: 12;
    }
  }

  HoverHandler {
    id: hoverHandler;
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad;
  }

  // Only live while a notification is showing — CenterWidget's own
  // tap-to-open-panel handler checks suppressPanelOpen above and skips
  // itself in that case, so this is the only thing a tap does here.
  // TapHandlers on separate items aren't mutually exclusive (learned the
  // hard way with the command-center panel earlier), so this explicitly
  // ignores taps that land on closeBtn rather than trusting it won't also
  // fire alongside closeBtn's own handler.
  TapHandler {
    enabled: clock.hasNotification;
    acceptedButtons: Qt.LeftButton;
    onTapped: (eventPoint) => {
      var p = eventPoint.position;
      var onCloseBtn = closeBtn.visible
        && p.x >= closeBtn.x && p.x <= closeBtn.x + closeBtn.width
        && p.y >= closeBtn.y && p.y <= closeBtn.y + closeBtn.height;
      if (onCloseBtn) return;
      var n = Services.NotificationService.latestNotification;
      if (n) Services.NotificationService.invokeDefaultAction(n);
    }
  }
}
