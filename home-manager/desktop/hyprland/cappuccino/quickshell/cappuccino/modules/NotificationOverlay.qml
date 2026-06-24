import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications


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

  readonly property int toastWidth:    320;
  readonly property int toastRadius:   14;
  readonly property int toastPadding:  15;
  readonly property int spacing:       5;
  readonly property int rightOffset:   10;
  readonly property int topOffset:     5;
  readonly property int slideInMs:     220;
  readonly property int removeMs:      200;

  readonly property int contentHeight:  50;

  readonly property int  actionHeight:   26;
  readonly property int  actionRadius:   8;
  readonly property int  actionSpacing:  6;
  readonly property int  actionHPadding: 12;
  readonly property int  actionFontSize: 11;
  readonly property int  actionIconSize: 14;

  visible: true;
  color: "transparent";
  exclusionMode: ExclusionMode.Ignore;

  anchors { top: true; right: true; }
  margins { top: topOffset + Theme.barHeight + Theme.defaultMargin; right: rightOffset; }

  implicitWidth: toastWidth;
  implicitHeight: Math.max(1, column.implicitHeight);

  ColumnLayout {
    id: column;
    width: parent.width;
    spacing: overlay.spacing;

    Repeater {
      model: Services.NotificationService.trackedNotifications;
      delegate: Rectangle {
        id: card;
        required property var modelData;

        property int fadeMs: Services.NotificationService.fadeDuration;
        Behavior on opacity {
          NumberAnimation { duration: card.fadeMs; easing.type: Easing.OutCubic }
        }

        Connections {
          target: Services.NotificationService;
          function onFadeOut(notification) {
            if (notification.id !== card.modelData.id) return;
            card.fadeMs = Services.NotificationService.fadeDuration;
            card.opacity = 0;
          }
          function onFadeIn(notification) {
            if (notification.id !== card.modelData.id) return;
            card.fadeMs = Services.NotificationService.fadeInDuration;
            card.opacity = 1;
          }
        }

        HoverHandler {
          id: cardHover;
          onHoveredChanged: cardHover.hovered
            ? Services.NotificationService.stopTimer(card.modelData)
            : Services.NotificationService.resetTimer(card.modelData);
        }

        Layout.fillWidth: true;
        Layout.preferredHeight: body.implicitHeight + overlay.toastPadding * 2;

        radius: overlay.toastRadius;
        color: Theme.current.surface0;
        border.width: 2;
        border.color: card.modelData.urgency === NotificationUrgency.Critical ? Theme.current.red
                    : card.modelData.urgency === NotificationUrgency.Normal ? Theme.current.blue
                    : Theme.current.overlay1;

        ColumnLayout {
          id: body;
          anchors {
            left: parent.left;
            right: parent.right;
            top: parent.top;
            margins: overlay.toastPadding;
          }
          spacing: overlay.actionSpacing;

          RowLayout {
            id: content;
            Layout.fillWidth: true;
            Layout.preferredHeight: Math.max(overlay.contentHeight, textColumn.implicitHeight);
            Layout.rightMargin: 22;
            spacing: overlay.spacing;

            Image {
              id: icon;
              readonly property int box: overlay.contentHeight - 20;
              Layout.alignment: Qt.AlignTop;
              Layout.topMargin: 10;
              Layout.leftMargin: 4;
              Layout.rightMargin: 10;

              Layout.preferredHeight: icon.box;
              Layout.preferredWidth: icon.implicitHeight > 0
                                   ? icon.box * icon.implicitWidth / icon.implicitHeight
                                   : icon.box;
              fillMode: Image.PreserveAspectFit;
              visible: source.toString() !== "";
              source: {
                if (card.modelData.image) return card.modelData.image;
                var ic = card.modelData.appIcon;
                if (!ic) return "";
                if (ic.startsWith("/") || ic.indexOf("://") !== -1) return ic;
                return Quickshell.iconPath(ic, true);
              }
            }

            ColumnLayout {
              id: textColumn;
              Layout.fillWidth: true;
              Layout.alignment: Qt.AlignVCenter;
              spacing: 2;

              Text {
                text: card.modelData.summary || "";
                color: Theme.current.text;
                font.pixelSize: 13;
                font.weight: Font.DemiBold;
                elide: Text.ElideRight;
                Layout.fillWidth: true;
              }

              Text {
                id: bodyText;
                property bool copied: false;
                visible: card.modelData.body !== "";
                text: copied ? (card.modelData.body || "").replace("</a>", "</a> 📋")
                             : (card.modelData.body || "");
                color: Theme.current.subtext0;
                font.pixelSize: 12;
                wrapMode: Text.WordWrap;
                maximumLineCount: 2;
                Layout.fillWidth: true;

                textFormat: Text.StyledText;
                linkColor: Theme.current.sapphire;
                onLinkActivated: link => Qt.openUrlExternally(link);

                Timer { id: copiedReset; interval: 1500; onTriggered: bodyText.copied = false; }

                MouseArea {
                  anchors.fill: parent;
                  acceptedButtons: Qt.RightButton;
                  cursorShape: bodyText.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor;
                  onClicked: mouse => {
                    var link = bodyText.linkAt(mouse.x, mouse.y);
                    if (!link) return;
                    Quickshell.execDetached(["wl-copy", link]);
                    bodyText.copied = true;
                    copiedReset.restart();
                  }
                }
              }

              Text {
                visible: card.modelData.appName !== "";
                text: card.modelData.appName || "";
                color: Theme.current.overlay1;
                font.pixelSize: 11;
                Layout.fillWidth: true;
              }
            }
          }

          Flow {
            id: actionRow;
            Layout.fillWidth: true;
            visible: card.modelData.actions.length > 0;
            spacing: overlay.actionSpacing;

            Repeater {
              model: card.modelData.actions;
              delegate: Rectangle {
                id: actionBtn;
                required property var modelData;
                readonly property bool hasIcon:
                  card.modelData.hasActionIcons && actionBtn.modelData.identifier !== "";

                implicitWidth: actionContent.implicitWidth + overlay.actionHPadding * 2;
                implicitHeight: overlay.actionHeight;
                radius: overlay.actionRadius;
                color: actionHover.hovered ? Theme.current.surface2 : Theme.current.surface1;

                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                  id: actionContent;
                  anchors.centerIn: parent;
                  spacing: 5;

                  Image {
                    id: actionIcon;
                    visible: actionBtn.hasIcon && source.toString() !== "";
                    anchors.verticalCenter: parent.verticalCenter;
                    width: overlay.actionIconSize;
                    height: overlay.actionIconSize;
                    sourceSize.width: overlay.actionIconSize;
                    sourceSize.height: overlay.actionIconSize;
                    fillMode: Image.PreserveAspectFit;
                    source: actionBtn.hasIcon
                          ? Quickshell.iconPath(actionBtn.modelData.identifier, true)
                          : "";
                  }

                  Text {
                    id: actionLabel;
                    anchors.verticalCenter: parent.verticalCenter;
                    visible: text.length > 0;
                    text: actionBtn.modelData.text;
                    color: actionHover.hovered ? Theme.current.text : Theme.current.subtext0;
                    font.pixelSize: overlay.actionFontSize;
                    font.weight: Font.Medium;

                    Behavior on color { ColorAnimation { duration: 100 } }
                  }
                }

                HoverHandler { id: actionHover; }

                TapHandler {
                  onTapped: actionBtn.modelData.invoke();
                }
              }
            }
          }
        }

        Rectangle {
          id: closeBtn;
          width: 22;
          height: 22;
          radius: 11;
          color: closeHover.hovered ? Theme.current.surface2 : "transparent";
          anchors { right: parent.right; top: parent.top; rightMargin: 6; topMargin: 6; }

          Behavior on color { ColorAnimation { duration: 100 } }

          Text {
            text: "×";
            color: closeHover.hovered ? Theme.current.text : Theme.current.overlay1;
            font.pixelSize: 14;
            anchors.centerIn: parent;

            Behavior on color { ColorAnimation { duration: 100 } }
          }

          HoverHandler { id: closeHover; }

          TapHandler {
            onTapped: card.modelData.dismiss();
          }
        }
      }
    }
  }

}
