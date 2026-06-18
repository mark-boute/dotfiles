import QtQuick
import QtQuick.Layouts
import Quickshell

import qs
import qs.services as Services

// Always-present overlay so Hyprland maintains pointer focus on this surface.
// Input is gated via `mask` — empty when no toasts, filled when toasts are shown.
// This avoids the "new surface on visible=true gets no button events until cursor
// leaves and re-enters" problem with conditionally-visible PanelWindows.
PanelWindow {
  id: overlay;
  required property var modelData;
  screen: modelData;

  visible: true;
  color: "transparent";
  exclusiveZone: 0;

  anchors { top: true; left: true; right: true; }

  readonly property int toastWidth:    320;
  readonly property int toastRadius:   14;
  readonly property int toastPadding:  16;
  readonly property int spacing:       5;
  readonly property int rightOffset:   10;
  readonly property int topOffset:     5;
  readonly property int holdDelay:     10000;
  readonly property int fadeDuration:  5000;
  readonly property int slideInMs:     220;
  readonly property int removeMs:      200;

  // Mask: covers only the toast column. Zero height when no toasts → no input
  // interception anywhere on screen while idle.
  mask: Region {
    x: overlay.width - overlay.toastWidth - overlay.rightOffset
    y: overlay.topOffset
    width: overlay.toastWidth
    height: Services.NotificationService.toasts.count > 0
            ? toastList.contentHeight
              + Math.max(0, toastList.count - 1) * toastList.spacing
              + overlay.topOffset
            : 0
  }

  implicitHeight: Math.max(1,
                  toastList.contentHeight
                  + Math.max(0, toastList.count - 1) * toastList.spacing
                  + topOffset);

  ListView {
    id: toastList;
    width: overlay.toastWidth;
    height: contentHeight;
    interactive: false;
    spacing: overlay.spacing;
    anchors { top: parent.top; right: parent.right; rightMargin: overlay.rightOffset; topMargin: overlay.topOffset; }

    model: Services.NotificationService.toasts;

    add: Transition {
      ParallelAnimation {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: overlay.slideInMs - 20; easing.type: Easing.OutCubic }
        NumberAnimation { property: "x"; from: 12; to: 0; duration: overlay.slideInMs; easing.type: Easing.OutCubic }
      }
    }

    remove: Transition {
      ParallelAnimation {
        NumberAnimation { property: "opacity"; to: 0; duration: overlay.removeMs - 40; easing.type: Easing.OutCubic }
        NumberAnimation { property: "x"; to: 12; duration: overlay.removeMs - 40; easing.type: Easing.OutCubic }
        NumberAnimation { property: "height"; to: 0; duration: overlay.removeMs; easing.type: Easing.OutCubic }
      }
    }

    displaced: Transition {
      NumberAnimation { property: "y"; duration: overlay.removeMs - 20; easing.type: Easing.OutCubic }
    }

    delegate: Rectangle {
      id: toast;
      required property int    notifId;
      required property string summary;
      required property string body;
      required property string appName;
      required property int    urgency;
      required property int    timeout;

      width: overlay.toastWidth;
      height: toastContent.implicitHeight + overlay.toastPadding;
      radius: overlay.toastRadius;
      color: Theme.current.surface0;
      border.width: 2;
      border.color: toast.urgency === 2 ? Theme.current.red
                  : toast.urgency === 0 ? Theme.current.overlay1
                  : Theme.current.blue;

      // Whether this toast was the last one hovered — used to know when to restart
      // the hold timer after the cursor leaves, even from another screen's delegate.
      property bool wasHovered: false;

      HoverHandler {
        id: toastHover;
        onHoveredChanged: {
          if (toastHover.hovered) {
            Services.NotificationService.hoveredNotifId = toast.notifId;
          } else if (Services.NotificationService.hoveredNotifId === toast.notifId) {
            Services.NotificationService.hoveredNotifId = -1;
          }
        }
      }

      // React to hover changes from ANY screen's delegate for this notification.
      Connections {
        target: Services.NotificationService;
        function onHoveredNotifIdChanged() {
          var hov = Services.NotificationService.hoveredNotifId;
          if (hov === toast.notifId) {
            toast.wasHovered = true;
            holdTimer.stop();
            dismissTimer.stop();
            fadeAnim.stop();
            toast.opacity = 1;
          } else if (toast.wasHovered) {
            toast.wasHovered = false;
            holdTimer.restart();
          }
        }
      }

      Timer {
        id: holdTimer;
        interval: overlay.holdDelay;
        onTriggered: { fadeAnim.restart(); dismissTimer.restart(); }
      }

      Timer {
        id: dismissTimer;
        interval: overlay.fadeDuration;
        onTriggered: Services.NotificationService.dismiss(toast.notifId);
      }

      NumberAnimation {
        id: fadeAnim;
        target: toast; property: "opacity";
        from: 1; to: 0;
        duration: overlay.fadeDuration;
        easing.type: Easing.Linear;
      }

      Component.onCompleted: holdTimer.start();

      ColumnLayout {
        id: toastContent;
        spacing: 2;
        anchors {
          left: parent.left;
          right: closeBtn.left;
          verticalCenter: parent.verticalCenter;
          leftMargin: 14;
          rightMargin: 4;
        }

        Text {
          text: toast.summary;
          color: Theme.current.text;
          font.pixelSize: 13;
          font.weight: Font.DemiBold;
          elide: Text.ElideRight;
          Layout.fillWidth: true;
        }

        Text {
          visible: toast.body.length > 0;
          text: toast.body;
          color: Theme.current.subtext0;
          font.pixelSize: 12;
          wrapMode: Text.WordWrap;
          maximumLineCount: 2;
          elide: Text.ElideRight;
          Layout.fillWidth: true;
        }

        Text {
          text: toast.appName;
          color: Theme.current.overlay1;
          font.pixelSize: 11;
          Layout.fillWidth: true;
        }
      }

      Rectangle {
        id: closeBtn;
        width: 22;
        height: 22;
        radius: 11;
        color: toastHover.hovered ? Theme.current.surface2 : "transparent";
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter; }

        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
          text: "×";
          color: toastHover.hovered ? Theme.current.text : Theme.current.overlay1;
          font.pixelSize: 14;
          anchors.centerIn: parent;

          Behavior on color { ColorAnimation { duration: 100 } }
        }

        TapHandler {
          onTapped: {
            holdTimer.stop();
            dismissTimer.stop();
            fadeAnim.stop();
            Services.NotificationService.dismiss(toast.notifId);
          }
        }
      }
    }
  }
}
