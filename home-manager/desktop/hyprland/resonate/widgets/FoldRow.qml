import QtQuick
import QtQuick.Layouts

import qs

// One 36px row in a system-panel foldout: signal bars or an icon, a name, a
// status, and an optional trailing glyph (lock, check).
Rectangle {
  id: row;

  property string name: "";
  property string status: "";
  property bool bold: false;
  property bool highlighted: false;
  property bool busy: false;       // spinner next to the name
  property int bars: -1;          // 0..4 signal bars, -1 for none
  property string glyph: "";      // leading icon when there are no bars
  property string trailGlyph: "";
  property color trailColor: CurrentTheme.subtext;
  signal tapped();

  implicitHeight: 36;
  radius: 10;
  color: hover.hovered ? CurrentTheme.surfaceHover : highlighted ? CurrentTheme.chip : "transparent";
  Behavior on color { ColorAnimation { duration: 100 } }

  RowLayout {
    anchors.fill: parent;
    anchors.leftMargin: 10;
    anchors.rightMargin: 10;
    spacing: 10;

    Item {
      visible: row.bars >= 0;
      implicitWidth: 16; implicitHeight: 12;
      Repeater {
        model: 4;
        Rectangle {
          required property int index;
          x: [0, 4, 9, 13][index];
          anchors.bottom: parent.bottom;
          width: 3; height: 3 * (index + 1);
          radius: 1;
          color: index < row.bars ? CurrentTheme.text
            : Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.2);
        }
      }
    }
    Text {
      visible: row.bars < 0 && row.glyph !== "";
      Layout.preferredWidth: 16;
      horizontalAlignment: Text.AlignHCenter;
      text: row.glyph;
      font.family: Theme.iconFontFamily;
      font.pixelSize: 15;
      color: CurrentTheme.text;
    }
    Text {
      Layout.fillWidth: true;
      Layout.minimumWidth: 0;
      Layout.maximumWidth: implicitWidth;
      text: row.name;
      elide: Text.ElideRight;
      color: CurrentTheme.text;
      font.pixelSize: 12;
      font.weight: row.bold ? Font.Bold : Font.Normal;
    }
    Text {
      visible: row.busy;
      text: String.fromCodePoint(0xf0772); // md-loading
      font.family: Theme.iconFontFamily;
      font.pixelSize: 13;
      color: CurrentTheme.subtext;
      RotationAnimation on rotation {
        running: row.busy;
        from: 0; to: 360; duration: 900;
        loops: Animation.Infinite;
      }
    }
    Item { Layout.fillWidth: true; }
    Text {
      visible: row.status !== "";
      text: row.status;
      color: CurrentTheme.subtext;
      font.pixelSize: 11;
    }
    Text {
      visible: row.trailGlyph !== "";
      text: row.trailGlyph;
      font.family: Theme.iconFontFamily;
      font.pixelSize: 12;
      color: row.trailColor;
    }
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; }
  TapHandler { onTapped: row.tapped(); }
}
