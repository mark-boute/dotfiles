import QtQuick
import QtQuick.Layouts

import qs

// A status pill for the power panel — icon, label, and a status subtitle,
// filled with the accent color when active (matching the "turquoise when
// on" reference look) rather than a plain flat surface.
Rectangle {
  id: tile;

  // A Nerd Font glyph (see Theme.iconFontFamily), not an icon-theme file —
  // icon-theme lookups (IconImage) render their own baked-in color with no
  // easy way to retint them; a font glyph is just colored Text like
  // anything else, which is the whole reason to use one here.
  property string iconGlyph: "";
  property string label: "";
  property string status: "";
  property bool active: false;
  signal tapped();

  radius: height / 2;
  implicitHeight: 52;
  color: active ? CurrentTheme.accent : CurrentTheme.background;
  border.width: active ? 0 : 1;
  border.color: CurrentTheme.border;

  readonly property color contentColor: active ? CurrentTheme.background : CurrentTheme.text;
  readonly property color subtextColor: active ? Qt.rgba(CurrentTheme.background.r, CurrentTheme.background.g, CurrentTheme.background.b, 0.7) : CurrentTheme.subtext;

  Behavior on color { ColorAnimation { duration: 140 } }

  RowLayout {
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 10; }
    spacing: 10;

    Text {
      text: tile.iconGlyph;
      font.family: Theme.iconFontFamily;
      font.pixelSize: 18;
      color: tile.contentColor;
    }

    ColumnLayout {
      spacing: 0;
      Layout.fillWidth: true;

      Text {
        text: tile.label;
        color: tile.contentColor;
        font.pixelSize: 13;
        font.weight: Font.DemiBold;
        elide: Text.ElideRight;
        Layout.fillWidth: true;
      }

      Text {
        visible: tile.status !== "";
        text: tile.status;
        color: tile.subtextColor;
        font.pixelSize: 11;
        elide: Text.ElideRight;
        Layout.fillWidth: true;
      }
    }
  }

  TapHandler {
    onTapped: tile.tapped();
  }
}
