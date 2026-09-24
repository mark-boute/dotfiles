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
  readonly property var history: Services.NotificationService.history;
  property bool showHistory: false;

  // Height this section may take (ControlPanel works it out). The header and
  // the Earlier row always show; the cards and the opened history share the
  // rest, each scrolling past its share.
  property real maxHeight: 100000;
  readonly property real avail: Math.max(0, maxHeight - headerRow.implicitHeight - earlierRow.implicitHeight
    - (placeholder.visible ? placeholder.implicitHeight + Theme.defaultSpacing * 2 : 0) - spacing * 3);
  readonly property real historyH: (showHistory && history.length > 0)
    ? Math.min(historyList.contentHeight, count > 0 ? avail * 0.45 : avail) : 0;
  readonly property real cardsH: count > 0 ? Math.max(0, Math.min(notifList.contentHeight, avail - historyH)) : 0;

  function ago(ts) {
    var s = Math.max(0, (Date.now() - ts) / 1000);
    if (s < 60) return "now";
    if (s < 3600) return Math.floor(s / 60) + "m";
    if (s < 86400) return Math.floor(s / 3600) + "h";
    return Math.floor(s / 86400) + "d";
  }

  RowLayout {
    id: headerRow;
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
      color: CurrentTheme.subtext;
      font.pixelSize: 11; font.weight: Font.DemiBold;
    }
    Item { Layout.fillWidth: true }
    Text {
      text: String.fromCodePoint(Services.NotificationService.dnd ? 0xf09a2 : 0xf009a); // bell-off / bell
      font.family: Theme.iconFontFamily;
      font.pixelSize: 13;
      color: Services.NotificationService.dnd ? CurrentTheme.text : CurrentTheme.subtext;
      HoverHandler { cursorShape: Qt.PointingHandCursor; }
      TapHandler { onTapped: Services.NotificationService.toggleDnd(); }
    }
    Text {
      visible: root.count > 0;
      text: "Clear all";
      color: CurrentTheme.subtext;
      font.pixelSize: 11; font.weight: Font.DemiBold;
      TapHandler { onTapped: Services.NotificationService.clearAll(); }
    }
  }

  Text {
    Layout.fillWidth: true;
    Layout.bottomMargin: Theme.defaultSpacing;
    id: placeholder;
    visible: root.count === 0;
    text: "Nothing right now";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }

  ListView {
    id: notifList;
    Layout.fillWidth: true;
    Layout.preferredHeight: root.cardsH;
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

  // --- Earlier (persisted history) ---
  RowLayout {
    id: earlierRow;
    Layout.fillWidth: true;
    Layout.topMargin: 2;
    spacing: 6;

    Text {
      text: "Earlier";
      color: CurrentTheme.subtext;
      font.pixelSize: 11; font.weight: Font.DemiBold;
    }
    Text {
      text: root.history.length;
      color: CurrentTheme.subtext;
      font.pixelSize: 10;
    }
    Item { Layout.fillWidth: true }
    Text {
      visible: root.showHistory && root.history.length > 0;
      text: "Clear";
      color: CurrentTheme.subtext;
      font.pixelSize: 11; font.weight: Font.DemiBold;
      TapHandler { onTapped: Services.NotificationService.clearHistory(); }
    }
    Text {
      text: String.fromCodePoint(root.showHistory && root.history.length > 0 ? 0xf0143 : 0xf0140); // chevron up/down
      font.family: Theme.iconFontFamily;
      font.pixelSize: Theme.iconSize;
      color: CurrentTheme.subtext;
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor; }
    TapHandler { enabled: root.history.length > 0; onTapped: root.showHistory = !root.showHistory; }
  }

  ListView {
    id: historyList;
    visible: root.showHistory && root.history.length > 0;
    Layout.fillWidth: true;
    Layout.preferredHeight: root.historyH;
    clip: true;
    interactive: contentHeight > height;
    spacing: 4;
    model: root.history;

    delegate: RowLayout {
      required property var modelData;
      width: ListView.view ? ListView.view.width : implicitWidth;
      spacing: 7;

      IconImage {
        implicitSize: 13;
        Layout.alignment: Qt.AlignTop;
        Layout.topMargin: 1;
        visible: source.toString() !== "";
        source: {
          var m = modelData;
          if (m.image) return m.image;
          if (!m.icon) return "";
          return (m.icon.startsWith("/") || m.icon.indexOf("://") !== -1)
            ? m.icon : Quickshell.iconPath(m.icon, true);
        }
      }
      ColumnLayout {
        Layout.fillWidth: true;
        spacing: 0;
        Text {
          Layout.fillWidth: true;
          text: modelData.summary || modelData.app;
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
          elide: Text.ElideRight;
        }
        Text {
          Layout.fillWidth: true;
          visible: modelData.body !== "";
          text: modelData.body;
          color: CurrentTheme.subtext;
          font.pixelSize: 10;
          opacity: 0.7;
          elide: Text.ElideRight;
        }
      }
      Text {
        text: root.ago(modelData.ts);
        color: CurrentTheme.subtext;
        font.pixelSize: 9;
        Layout.alignment: Qt.AlignTop;
      }
    }
  }
}
