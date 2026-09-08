import QtQuick

import qs

// A full-width fillable slider pill — shared shape for volume/brightness/
// color-temperature. Always at least a full pill-diameter circle, even at
// value 0, growing proportionally from there (no flat minimum-width
// clamp, no floor-less squish at low values either) — see the fillWidth
// comment below for why the formula is written the way it is.
Rectangle {
  id: track;

  property real value: 0; // 0..1
  property string valueLabel: "";
  property color fillColor: CurrentTheme.accent;
  // White-temperature slider: the fill is a cool→warm gradient (blue at 0,
  // amber at 1) that stretches with the fill instead of a flat fillColor —
  // so its rounded end matches every other bar.
  property bool temperature: false;

  implicitHeight: 40;
  radius: height / 2;
  color: CurrentTheme.backgroundGlass;
  opacity: enabled ? 1 : 0.4;
  clip: true;

  signal moved(real fraction);

  // Exposed so a consumer can gate its own live-polled state updates while
  // the user is mid-drag (a poll landing mid-drag would otherwise yank the
  // fill back to the last-known server value out from under the pointer).
  readonly property alias dragging: dragHandler.active;

  readonly property real minFillWidth: radius * 2;
  readonly property real fillWidth: {
    var v = Math.max(0, Math.min(1, track.value));
    return minFillWidth + (width - minFillWidth) * v;
  }

  Rectangle {
    id: fill;
    height: parent.height;
    radius: parent.radius;
    width: track.fillWidth;
    color: track.temperature ? "transparent" : track.fillColor;

    Behavior on color { ColorAnimation { duration: 140 } }

    // Cool→warm gradient for the temperature slider. Sized to the fill (not
    // clipped from a fixed-width strip, which left a straight vertical cut)
    // so it stretches as the fill grows and its rounded end matches the
    // other bars.
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

    // A child of the fill itself (not the track) so it rides along with
    // the fill's own right edge as it grows/shrinks, rather than sitting
    // at a fixed spot on the track.
    Text {
      anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter; }
      text: track.valueLabel;
      font.pixelSize: 12;
      font.weight: Font.DemiBold;
      color: CurrentTheme.background;
    }
  }

  TapHandler {
    enabled: track.enabled;
    onTapped: (eventPoint) => track.moved(eventPoint.position.x / track.width);
  }

  DragHandler {
    id: dragHandler;
    enabled: track.enabled;
    target: null;
    onCentroidChanged: {
      if (!active) return;
      track.moved(centroid.position.x / track.width);
    }
  }

  // MouseArea, not WheelHandler — WheelHandler silently did nothing here
  // for reasons that weren't worth chasing further. acceptedButtons:
  // NoButton so this only ever handles wheel; clicking/dragging stays on
  // the TapHandler/DragHandler above.
  MouseArea {
    anchors.fill: parent;
    enabled: track.enabled;
    acceptedButtons: Qt.NoButton;
    onWheel: (wheel) => {
      var step = 0.05;
      track.moved(Math.max(0, Math.min(1, track.value + (wheel.angleDelta.y > 0 ? step : -step))));
    }
  }
}
