import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.services as Services

// The always-present notification centre at the bottom of the panel's home
// view. Header with a count + "Clear all"; a scrolling list of cards, or a
// quiet placeholder when empty.
ColumnLayout {
  id: root;
  spacing: Theme.defaultSpacing;

  readonly property var notes: Services.NotificationService.trackedNotifications;
  readonly property int count: notes.values.length;

  RowLayout {
    Layout.fillWidth: true;
    spacing: 6;

    Text {
      text: "Notifications";
      color: CurrentTheme.subtext;
      font.pixelSize: 12; font.weight: Font.DemiBold;
    }
    Text {
      visible: root.count > 0;
      text: root.count;
      color: CurrentTheme.accent;
      font.pixelSize: 11; font.weight: Font.DemiBold;
    }
    Item { Layout.fillWidth: true }
    Text {
      visible: root.count > 0;
      text: "Clear all";
      color: CurrentTheme.accent;
      font.pixelSize: 11; font.weight: Font.DemiBold;
      TapHandler { onTapped: Services.NotificationService.clearAll(); }
    }
  }

  Text {
    Layout.fillWidth: true;
    Layout.bottomMargin: Theme.defaultSpacing;
    visible: root.count === 0;
    text: "Nothing right now";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }

  ListView {
    id: notifList;
    Layout.fillWidth: true;
    Layout.preferredHeight: Math.min(contentHeight, 340);
    visible: root.count > 0;
    clip: true;
    interactive: contentHeight > height;
    spacing: 6;
    model: root.notes;

    delegate: Rectangle {
      id: card;
      required property var modelData;
      width: notifList.width;
      height: body.implicitHeight + 20;
      radius: 12;
      color: CurrentTheme.backgroundGlass;
      border.width: 1;
      border.color: CurrentTheme.border;

      ColumnLayout {
        id: body;
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; }
        spacing: 2;

        RowLayout {
          Layout.fillWidth: true;
          spacing: 6;

          IconImage {
            implicitSize: 14;
            visible: source.toString() !== "";
            source: {
              var n = card.modelData;
              if (n.image) return n.image;
              var ic = n.appIcon;
              if (!ic) return "";
              return (ic.startsWith("/") || ic.indexOf("://") !== -1) ? ic : Quickshell.iconPath(ic, true);
            }
          }
          Text {
            text: card.modelData.appName;
            color: CurrentTheme.subtext;
            font.pixelSize: 10;
            Layout.fillWidth: true;
          }
          Rectangle {
            id: removeBtn;
            Layout.alignment: Qt.AlignVCenter;
            implicitWidth: 22; implicitHeight: 22;
            radius: 7;
            color: removeHover.hovered ? CurrentTheme.surfaceHover : "transparent";
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
              anchors.centerIn: parent;
              text: String.fromCodePoint(0xf014); // trash — removes from the list
              font.family: Theme.iconFontFamily;
              font.pixelSize: 12;
              color: removeHover.hovered ? CurrentTheme.danger : CurrentTheme.subtext;
            }

            HoverHandler { id: removeHover; cursorShape: Qt.PointingHandCursor; }
            TapHandler { onTapped: card.modelData.dismiss(); }
          }
        }

        Text {
          Layout.fillWidth: true;
          text: card.modelData.summary;
          color: CurrentTheme.text;
          font.pixelSize: 12; font.weight: Font.DemiBold;
          elide: Text.ElideRight;
        }
        Text {
          Layout.fillWidth: true;
          visible: card.modelData.body !== "";
          text: card.modelData.body;
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
          wrapMode: Text.WordWrap;
          maximumLineCount: 3;
          elide: Text.ElideRight;
        }
      }
    }
  }
}
