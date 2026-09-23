import QtQuick

import qs

// A pill of equal segments with a sliding accent highlight on the current
// one. Each option is { glyph: <icon codepoint> } or { text: "..." }.
Rectangle {
  id: slider;

  property var options: [];
  property int currentIndex: 0;
  // A second, faint highlight — e.g. which profile "auto" has picked.
  property int hintIndex: -1;
  readonly property real segmentWidth: width / Math.max(1, options.length);
  signal picked(int index);

  implicitWidth: options.length * 38;
  implicitHeight: 34;
  radius: 9;
  opacity: enabled ? 1 : 0.4;
  color: CurrentTheme.backgroundGlass;
  border.width: 1;
  border.color: CurrentTheme.border;

  Rectangle {
    visible: slider.hintIndex >= 0 && slider.hintIndex !== slider.currentIndex;
    // Inset so it sits inside the pill's border rather than over it.
    x: slider.hintIndex * slider.segmentWidth + 3;
    y: 3;
    width: slider.segmentWidth - 6;
    height: parent.height - 6;
    radius: parent.radius - 3;
    color: Qt.rgba(CurrentTheme.accent.r, CurrentTheme.accent.g, CurrentTheme.accent.b, 0.18);
    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }

  Rectangle {
    x: slider.currentIndex * slider.segmentWidth;
    width: slider.segmentWidth;
    height: parent.height;
    radius: parent.radius;
    color: CurrentTheme.accent;
    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }

  Row {
    anchors.fill: parent;
    Repeater {
      model: slider.options;
      delegate: Item {
        id: seg;
        required property var modelData;
        required property int index;
        width: slider.segmentWidth;
        height: slider.height;

        Text {
          anchors.centerIn: parent;
          text: seg.modelData.glyph !== undefined ? String.fromCodePoint(seg.modelData.glyph) : seg.modelData.text;
          font.family: Theme.iconFontFamily; // a Nerd Font is JetBrains Mono plus icons, so plain text renders fine
          font.pixelSize: seg.modelData.glyph !== undefined ? 14 : 12;
          font.weight: Font.Bold;
          color: seg.index === slider.currentIndex ? CurrentTheme.background : CurrentTheme.text;
        }
        HoverHandler { enabled: slider.enabled; cursorShape: Qt.PointingHandCursor; }
        TapHandler { enabled: slider.enabled; onTapped: slider.picked(seg.index); }
      }
    }
  }
}
