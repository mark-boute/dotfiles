import QtQuick
import QtQuick.Layouts

import qs

// One row in the launcher's result lists (apps / documents / open-with).
// Folder rows carry a ">" button (chevronTapped) that browses into the
// folder; a tap on the rest of the row emits `triggered`.
Rectangle {
  id: row;

  property bool selected: false;
  property string iconSource: "";
  property int glyph: 0;          // Nerd Font codepoint, used when iconSource is empty
  property string title: "";
  property string subtitle: "";
  property bool hasChevron: false;

  signal triggered();
  signal chevronTapped();

  width: ListView.view ? ListView.view.width : implicitWidth;
  implicitHeight: 44;
  radius: 9;
  color: selected
    ? Qt.rgba(CurrentTheme.accent.r, CurrentTheme.accent.g, CurrentTheme.accent.b, 0.20)
    : (hover.hovered ? CurrentTheme.surfaceHover : "transparent");
  Behavior on color { ColorAnimation { duration: 90 } }

  HoverHandler { id: hover; }

  RowLayout {
    anchors.fill: parent;
    anchors.leftMargin: 10;
    anchors.rightMargin: 10;
    spacing: 10;

    Item {
      id: body;
      Layout.fillWidth: true;
      Layout.fillHeight: true;

      RowLayout {
        anchors.fill: parent;
        spacing: 10;

        Item {
          Layout.preferredWidth: 24;
          Layout.preferredHeight: 24;

          Image {
            anchors.fill: parent;
            visible: row.iconSource !== "";
            source: row.iconSource;
            sourceSize.width: 24;
            sourceSize.height: 24;
            fillMode: Image.PreserveAspectFit;
            asynchronous: true;
          }
          Text {
            anchors.centerIn: parent;
            visible: row.iconSource === "" && row.glyph !== 0;
            text: row.glyph !== 0 ? String.fromCodePoint(row.glyph) : "";
            font.family: Theme.iconFontFamily;
            font.pixelSize: Theme.iconSize;
            color: CurrentTheme.subtext;
          }
        }

        ColumnLayout {
          Layout.fillWidth: true;
          spacing: 0;

          Text {
            Layout.fillWidth: true;
            text: row.title;
            color: CurrentTheme.text;
            font.pixelSize: 13;
            font.weight: Font.DemiBold;
            elide: Text.ElideRight;
          }
          Text {
            Layout.fillWidth: true;
            visible: row.subtitle !== "";
            text: row.subtitle;
            color: CurrentTheme.subtext;
            font.pixelSize: 10;
            elide: Text.ElideRight;
          }
        }
      }

      HoverHandler { cursorShape: Qt.PointingHandCursor; }
      TapHandler { onTapped: row.triggered(); }
    }

    Rectangle {
      visible: row.hasChevron;
      Layout.preferredWidth: 28;
      Layout.preferredHeight: 28;
      radius: 7;
      color: chevHover.hovered ? CurrentTheme.surfaceHover : "transparent";
      Behavior on color { ColorAnimation { duration: 90 } }

      Text {
        anchors.centerIn: parent;
        text: String.fromCodePoint(0xf0142); // chevron-right
        font.family: Theme.iconFontFamily;
        font.pixelSize: Theme.iconSize;
        color: chevHover.hovered ? CurrentTheme.text : CurrentTheme.subtext;
      }

      HoverHandler { id: chevHover; cursorShape: Qt.PointingHandCursor; }
      TapHandler { onTapped: row.chevronTapped(); }
    }
  }
}
