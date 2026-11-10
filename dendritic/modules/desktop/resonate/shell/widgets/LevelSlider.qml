import QtQuick

import qs

// The system panel's level slider: a glass track, a near-text fill that is
// never narrower than a circle (except at exactly 0), the icon riding inside
// the fill on the left and the value on the right. Tapping the icon emits
// iconTapped() instead of moving the value (volume uses it to mute).
Rectangle {
  id: track;

  property real value: 0; // 0..1
  property string valueLabel: Math.round(Math.max(0, Math.min(1, value)) * 100) + "%";
  property string glyph: "";
  property bool temperature: false;
  property bool dimmed: false;
  signal moved(real fraction);
  signal iconTapped();

  readonly property alias dragging: dragHandler.active;
  readonly property real _v: Math.max(0, Math.min(1, value));
  readonly property bool _covered: _v > 0;

  implicitHeight: 40;
  radius: height / 2;
  color: CurrentTheme.glass;
  border.width: 1;
  border.color: CurrentTheme.border;
  opacity: enabled ? 1 : 0.4;
  clip: true;

  Rectangle {
    id: fill;
    height: parent.height;
    radius: parent.radius;
    width: track._v === 0 ? 0 : Math.max(track.height, track.width * track._v);
    color: track.temperature ? "transparent"
      : track.dimmed ? Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.4)
      : CurrentTheme.fill;
    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
      visible: track.temperature;
      anchors.fill: parent;
      radius: parent.radius;
      gradient: Gradient {
        orientation: Gradient.Horizontal;
        GradientStop { position: 0.0; color: "#c2dbff" }
        GradientStop { position: 0.5; color: "#ffe0c2" }
        GradientStop { position: 1.0; color: "#ff9d4d" }
      }
    }
  }

  Text {
    id: icon;
    visible: track.glyph !== "";
    x: Math.round(track.height * 0.3);
    anchors.verticalCenter: parent.verticalCenter;
    text: track.glyph;
    font.family: Theme.iconFontFamily;
    font.pixelSize: Math.round(track.height * 0.45);
    color: track._covered ? CurrentTheme.onFill : CurrentTheme.text;
  }

  Text {
    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter; }
    visible: track.height >= 36;
    text: track.valueLabel;
    font.pixelSize: 11;
    font.weight: Font.Bold;
    color: fill.width > track.width - 44 ? CurrentTheme.onFill : CurrentTheme.subtext;
  }

  function _inIcon(x) { return icon.visible && x < track.height; }

  TapHandler {
    enabled: track.enabled;
    onTapped: (eventPoint) => {
      if (track._inIcon(eventPoint.position.x)) track.iconTapped();
      else track.moved(eventPoint.position.x / track.width);
    }
  }

  DragHandler {
    id: dragHandler;
    enabled: track.enabled;
    target: null;
    onCentroidChanged: {
      if (!active) return;
      track.moved(Math.max(0, Math.min(1, centroid.position.x / track.width)));
    }
  }

  MouseArea {
    anchors.fill: parent;
    enabled: track.enabled;
    acceptedButtons: Qt.NoButton;
    cursorShape: Qt.PointingHandCursor;
    onWheel: (wheel) => {
      track.moved(Math.max(0, Math.min(1, track._v + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))));
    }
  }
}
