import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.services as Services

// The center box's popout. Two modes:
//   home  — a header (time/date), now-playing, the apps drawer, the
//           notification centre.
//   app   — one drawer app taken over the whole panel (wider), with a
//           back arrow + title, system-tray-menu style.
//
// `openApp` drives the mode; ResizeBox resets it to "" each time the panel
// opens so you always land on home.
Item {
  id: panel;

  property string openApp: "";
  readonly property bool inApp: openApp !== "";

  // The bar window is full-width, so its Window.width is the monitor width; its
  // height is not the monitor height though, so screenHeight is fed in by
  // ResizeBox (from Bar's PanelWindow.screen) via a Binding.
  readonly property real screenW: Window.width > 0 ? Window.width : 1920;
  property real screenHeight: 0;

  // Tallest the panel may get before its body starts scrolling — the screen
  // minus room for the bar above and a little breathing space below.
  readonly property real maxHeight: Math.min(Theme.maxPanelContentHeight,
    (screenHeight > 0 ? screenHeight : 1080) - Theme.barHeight - Theme.defaultMargin * 4);

  readonly property int homeWidth: 340;
  // Each app declares the width it wants (bodyLoader.item.appWidth); the panel
  // gives it that, capped at 3/4 of the screen. Doesn't depend on the laid-out
  // width, so there's no sizing loop.
  readonly property int appWidthCap: Math.round(screenW * 0.75);
  readonly property int appWidth: {
    var want = (bodyLoader.item && bodyLoader.item.appWidth) ? bodyLoader.item.appWidth : 480;
    return Math.min(want, appWidthCap);
  }
  readonly property int contentW: inApp ? appWidth : homeWidth;

  readonly property real contentH:
    (headerLoader.item ? headerLoader.item.implicitHeight : 0)
    + Theme.defaultSpacing
    + (bodyLoader.item ? bodyLoader.item.implicitHeight : 0);

  // Grows to fit content, but never past maxHeight — beyond that the body
  // scrolls (see the Flickable below).
  implicitWidth: contentW + Theme.defaultMargin * 2;
  implicitHeight: Math.min(contentH, maxHeight) + Theme.defaultMargin * 2;

  // Both ease now — the real window is a fixed size (see Bar.qml), so
  // there's no longer a layer-shell reconfigure-per-frame cost to avoid by
  // snapping height.
  Behavior on implicitWidth { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
  Behavior on implicitHeight { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

  // Just the content now — the painted surface (fill + shadow + the outward
  // curve into the connecting strip) is BarSurface, one shared shape drawn
  // once for the whole bar in Bar.qml.
  Item {
    anchors.fill: parent;

    ColumnLayout {
      anchors.fill: parent;
      anchors.margins: Theme.defaultMargin;
      spacing: Theme.defaultSpacing;

      Loader {
        id: headerLoader;
        Layout.fillWidth: true;
        Layout.preferredHeight: item ? item.implicitHeight : 0;
        // Launcher takes over completely — its own search field is the header.
        sourceComponent: panel.openApp === "launcher" ? undefined
          : panel.inApp ? appHeader : homeHeader;
      }

      Flickable {
        id: bodyFlick;
        Layout.fillWidth: true;
        Layout.fillHeight: true;
        contentWidth: width;
        contentHeight: bodyLoader.item ? bodyLoader.item.implicitHeight : 0;
        clip: true;
        interactive: contentHeight > height;
        flickableDirection: Flickable.VerticalFlick;
        boundsBehavior: Flickable.StopAtBounds;

        MouseArea {
          anchors.fill: parent;
          acceptedButtons: Qt.NoButton;
          onWheel: (wheel) => {
            var max = Math.max(0, bodyFlick.contentHeight - bodyFlick.height);
            // Nothing to scroll here — let the wheel reach whatever's below
            // (e.g. the launcher's own result list).
            if (max <= 0) { wheel.accepted = false; return; }
            bodyFlick.contentY = Math.max(0, Math.min(max, bodyFlick.contentY - wheel.angleDelta.y));
          }
        }

        Loader {
          id: bodyLoader;
          width: bodyFlick.width;
          sourceComponent: panel.inApp
            ? (panel.openApp === "theme" ? themeApp
               : panel.openApp === "lights" ? lightsApp
               : panel.openApp === "launcher" ? launcherApp
               : panel.openApp === "assistant" ? assistantApp : checklistApp)
            : homeBody;
        }
      }
    }
  }

  // --- headers ---------------------------------------------------------------

  Component {
    id: homeHeader;
    ColumnLayout {
      width: headerLoader.width;
      spacing: 1;
      Text {
        Layout.alignment: Qt.AlignHCenter;
        text: Services.SystemClock.time;
        color: CurrentTheme.text;
        font.pixelSize: 26;
        font.weight: Font.Light;
      }
      Text {
        Layout.alignment: Qt.AlignHCenter;
        text: Services.SystemClock.weekday + ", " + Services.SystemClock.date;
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
      }
    }
  }

  Component {
    id: appHeader;
    Item {
      width: headerLoader.width;
      implicitHeight: 30;

      Row {
        anchors.left: parent.left;
        anchors.verticalCenter: parent.verticalCenter;
        spacing: 9;

        Rectangle {
          width: 26; height: 26; radius: 8;
          anchors.verticalCenter: parent.verticalCenter;
          color: backHover.hovered ? CurrentTheme.surfaceHover : "transparent";
          Behavior on color { ColorAnimation { duration: 100 } }
          Text {
            anchors.centerIn: parent;
            text: String.fromCodePoint(0xf053); // chevron-left
            font.family: Theme.iconFontFamily;
            font.pixelSize: 14;
            color: CurrentTheme.text;
          }
          HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor; }
          TapHandler { onTapped: panel.openApp = ""; }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter;
          text: panel.openApp === "theme" ? "Theme"
            : panel.openApp === "lights" ? "Lights"
            : panel.openApp === "assistant" ? "Assistant" : "Checklist";
          color: CurrentTheme.text;
          font.pixelSize: 15;
          font.weight: Font.DemiBold;
        }
      }
    }
  }

  // --- bodies ---------------------------------------------------------------

  Component {
    id: homeBody;
    ColumnLayout {
      width: bodyLoader.width;
      spacing: Theme.defaultSpacing;

      WeatherCard { id: weatherCard; Layout.fillWidth: true; }

      AppDrawer {
        id: drawer;
        Layout.fillWidth: true;
        onOpen: (appId) => panel.openApp = appId;
      }

      Rectangle {
        Layout.fillWidth: true;
        Layout.topMargin: Theme.defaultSpacing / 2;
        Layout.bottomMargin: Theme.defaultSpacing / 2;
        implicitHeight: 1;
        color: CurrentTheme.border;
      }

      // Whatever height the rest of home leaves; the list scrolls inside it,
      // so the panel keeps its bottom margin however many there are.
      NotificationCenter {
        Layout.fillWidth: true;
        maxHeight: panel.maxHeight
          - (headerLoader.item ? headerLoader.item.implicitHeight : 0) - Theme.defaultSpacing
          - weatherCard.implicitHeight - drawer.implicitHeight
          - (1 + Theme.defaultSpacing) - Theme.defaultSpacing * 3;
      }
    }
  }

  Component {
    id: themeApp;
    ThemeApp { width: bodyLoader.width; }
  }

  Component {
    id: checklistApp;
    ChecklistPanel {
      width: bodyLoader.width;
      panelW: bodyLoader.width;
    }
  }

  Component {
    id: lightsApp;
    LightsApp { width: bodyLoader.width; }
  }

  Component {
    id: launcherApp;
    LauncherApp { width: bodyLoader.width; }
  }

  Component {
    id: assistantApp;
    AssistantApp {
      width: bodyLoader.width;
      onBackRequested: panel.openApp = "";
    }
  }
}
