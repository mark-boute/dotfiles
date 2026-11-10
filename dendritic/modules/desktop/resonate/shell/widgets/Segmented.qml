import QtQuick
import QtQuick.Layouts

import qs

// A recessed segmented control: the chosen segment is filled near-text with
// base-coloured text. `dotIndex` marks one segment with a small accent dot
// (the profile auto mode picked). Options: [{ label, glyph? }]; with glyphs
// the icon sits above the label.
Rectangle {
  id: seg;

  property var options: [];
  property int currentIndex: 0;
  property int dotIndex: -1;
  signal picked(int index);

  implicitHeight: 32;
  radius: height >= 40 ? 12 : 10;
  color: CurrentTheme.well;
  opacity: enabled ? 1 : 0.45;

  RowLayout {
    anchors.fill: parent;
    anchors.margins: 3;
    spacing: 3;

    Repeater {
      model: seg.options;

      Rectangle {
        id: opt;
        required property var modelData;
        required property int index;
        readonly property bool chosen: seg.currentIndex === index;
        Layout.fillWidth: true;
        Layout.fillHeight: true;
        Layout.preferredWidth: 1;
        radius: seg.radius - 3;
        color: chosen ? CurrentTheme.fill
          : (hover.hovered ? CurrentTheme.chip : "transparent");
        Behavior on color { ColorAnimation { duration: 140 } }

        Column {
          anchors.centerIn: parent;
          spacing: 2;
          Text {
            visible: !!opt.modelData.glyph;
            anchors.horizontalCenter: parent.horizontalCenter;
            text: opt.modelData.glyph ? String.fromCodePoint(opt.modelData.glyph) : "";
            font.family: Theme.iconFontFamily;
            font.pixelSize: 14;
            color: opt.chosen ? CurrentTheme.onFill : CurrentTheme.text;
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter;
            text: opt.modelData.label;
            font.pixelSize: 11; font.weight: Font.Bold;
            color: opt.chosen ? CurrentTheme.onFill : CurrentTheme.text;
          }
        }

        Rectangle {
          visible: seg.dotIndex === opt.index;
          anchors { right: parent.right; top: parent.top; margins: 6; }
          width: 5; height: 5; radius: 2.5;
          color: CurrentTheme.accent;
        }

        HoverHandler { id: hover; enabled: seg.enabled; cursorShape: Qt.PointingHandCursor; }
        TapHandler { enabled: seg.enabled; onTapped: seg.picked(opt.index); }
      }
    }
  }
}
