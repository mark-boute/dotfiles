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

  implicitHeight: 40;
  radius: height / 2;
  color: CurrentTheme.background;
  opacity: enabled ? 1 : 0.4;
  clip: true;

  signal moved(real fraction);

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
    color: track.fillColor;

    Behavior on color { ColorAnimation { duration: 140 } }

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
