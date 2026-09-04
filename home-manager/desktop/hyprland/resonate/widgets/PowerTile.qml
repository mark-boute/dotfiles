import QtQuick
import QtQuick.Layouts

import qs

// A status pill for the power panel — icon, label, status subtitle, filled
// with the accent color when active. Optionally carries a dropdown chevron
// (expandable) that toggles a device list elsewhere in the panel; tapping the
// chevron emits toggleExpanded(), tapping anywhere else emits tapped().
Rectangle {
  id: tile;

  property string iconGlyph: "";
  property string label: "";
  property string status: "";
  property bool active: false;
  property bool expandable: false;
  property bool expanded: false;
  signal tapped();
  signal toggleExpanded();

  radius: height / 2;
  implicitHeight: 52;
  color: active ? CurrentTheme.accent : CurrentTheme.backgroundGlass;
  border.width: active ? 0 : 1;
  border.color: CurrentTheme.border;

  readonly property color contentColor: active ? CurrentTheme.background : CurrentTheme.text;
  readonly property color subtextColor: active ? Qt.rgba(CurrentTheme.background.r, CurrentTheme.background.g, CurrentTheme.background.b, 0.7) : CurrentTheme.subtext;

  Behavior on color { ColorAnimation { duration: 140 } }

  RowLayout {
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 6; }
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

    // Dropdown toggle — its own hit target, so it doesn't also toggle the radio.
    Rectangle {
      id: caret;
      visible: tile.expandable;
      Layout.alignment: Qt.AlignVCenter;
      implicitWidth: 30;
      implicitHeight: 30;
      radius: 15;
      color: caretHover.hovered
        ? (tile.active ? Qt.rgba(CurrentTheme.background.r, CurrentTheme.background.g, CurrentTheme.background.b, 0.25)
                       : CurrentTheme.surfaceHover)
        : "transparent";
      Behavior on color { ColorAnimation { duration: 100 } }

      Text {
        anchors.centerIn: parent;
        text: String.fromCodePoint(tile.expanded ? 0xf077 : 0xf078); // chevron up / down
        font.family: Theme.iconFontFamily;
        font.pixelSize: 11;
        color: tile.contentColor;
      }

      HoverHandler { id: caretHover; cursorShape: Qt.PointingHandCursor; }
      TapHandler { onTapped: tile.toggleExpanded(); }
    }
  }

  TapHandler {
    onTapped: (eventPoint) => {
      // Ignore taps that land on the caret — it has its own handler.
      if (tile.expandable) {
        var p = tile.mapFromItem(caret, 0, 0);
        if (eventPoint.position.x >= p.x && eventPoint.position.x <= p.x + caret.width)
          return;
      }
      tile.tapped();
    }
  }
}
