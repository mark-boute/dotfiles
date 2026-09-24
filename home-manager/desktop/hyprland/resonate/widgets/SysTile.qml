import QtQuick
import QtQuick.Layouts

import qs

// A 56px system-panel tile: an icon circle (accent when on), a title and a
// status line, and an optional chevron. The circle and the body can do
// different things (Wi-Fi: circle toggles the radio, body opens the list).
Rectangle {
  id: tile;

  property string glyph: "";
  property string title: "";
  property string sub: "";
  property bool on: false;
  property bool open: false;
  property string chevron: "";   // "", "down" (rotates with chevronTurn) or "right"
  property real chevronTurn: 0;  // 0..1
  signal tapped();
  signal iconTapped();

  implicitHeight: 56;
  radius: 16;
  color: open ? CurrentTheme.chip
    : hover.hovered ? Qt.tint(CurrentTheme.glass, Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.06))
    : CurrentTheme.glass;
  border.width: 1;
  border.color: CurrentTheme.border;
  Behavior on color { ColorAnimation { duration: 120 } }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; }
  TapHandler {
    onTapped: (p) => {
      var x = p.position.x;
      if (x >= 8 && x <= 48) tile.iconTapped(); else tile.tapped();
    }
  }

  RowLayout {
    anchors.fill: parent;
    anchors.leftMargin: 12;
    anchors.rightMargin: 6;
    spacing: 10;

    Rectangle {
      implicitWidth: 32; implicitHeight: 32; radius: 16;
      color: tile.on ? CurrentTheme.accent : CurrentTheme.off;
      Behavior on color { ColorAnimation { duration: 140 } }

      Text {
        anchors.centerIn: parent;
        text: tile.glyph;
        font.family: Theme.iconFontFamily;
        font.pixelSize: 16;
        color: tile.on ? CurrentTheme.onFill : CurrentTheme.text;
      }
    }

    ColumnLayout {
      Layout.fillWidth: true;
      spacing: 1;
      Text {
        Layout.fillWidth: true;
        text: tile.title;
        elide: Text.ElideRight;
        color: CurrentTheme.text;
        font.pixelSize: 13; font.weight: Font.Bold;
      }
      Text {
        Layout.fillWidth: true;
        text: tile.sub;
        elide: Text.ElideRight;
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
      }
    }

    Rectangle {
      visible: tile.chevron !== "";
      implicitWidth: 28; implicitHeight: 28; radius: 14;
      color: chevHover.hovered || (tile.open && tile.chevron === "down") ? CurrentTheme.chip : "transparent";
      Behavior on color { ColorAnimation { duration: 120 } }
      Text {
        anchors.centerIn: parent;
        text: String.fromCodePoint(tile.chevron === "right" ? 0xf0142 : 0xf0140); // md-chevron-right / -down
        rotation: tile.chevron === "down" ? 180 * tile.chevronTurn : 0;
        font.family: Theme.iconFontFamily;
        font.pixelSize: 16;
        color: CurrentTheme.subtext;
      }
      HoverHandler { id: chevHover; cursorShape: Qt.PointingHandCursor; }
    }
  }
}
