import QtQuick

import qs

// Saturation/value square + a separate hue strip — the <input type=color>
// shape, not a circular wheel: linear x/y -> sat/val needs no polar math and
// is the picker shape everyone already recognizes.
//
// `hue`/`sat`/`val` are plain properties — a caller (LightsApp.qml) seeds them
// directly (`wheel.hue = ...`) to reflect a polled bulb color; that alone
// never fires `changed`, only an actual drag/tap does, so seeding from a poll
// can never loop back into a spurious light write.
Item {
  id: wheel;

  property real hue: 0;   // 0-360
  property real sat: 1;   // 0-1
  property real val: 1;   // 0-1

  signal changed(real h, real s, real v);
  signal dragStarted();
  signal dragEnded();

  readonly property int svSize: 200;
  readonly property int hueBarHeight: 18;

  implicitWidth: svSize;
  implicitHeight: svSize + Theme.defaultSpacing + hueBarHeight + Theme.defaultSpacing + swatchRow.implicitHeight;

  Column {
    anchors.fill: parent;
    spacing: Theme.defaultSpacing;

    // --- saturation (x) / value (y) square ---
    Rectangle {
      id: svCard;
      width: wheel.svSize; height: wheel.svSize;
      radius: 12;
      color: CurrentTheme.backgroundGlass;
      border.width: 1;
      border.color: CurrentTheme.border;
      clip: true;

      Canvas {
        id: svCanvas;
        anchors.fill: parent;

        property real paintHue: wheel.hue;
        onPaintHueChanged: requestPaint();
        Component.onCompleted: requestPaint();

        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();

          var hueColor = Qt.hsva(paintHue / 360, 1, 1, 1);
          var gradH = ctx.createLinearGradient(0, 0, width, 0);
          gradH.addColorStop(0, "#ffffff");
          gradH.addColorStop(1, hueColor);
          ctx.fillStyle = gradH;
          ctx.fillRect(0, 0, width, height);

          var gradV = ctx.createLinearGradient(0, 0, 0, height);
          gradV.addColorStop(0, "rgba(0,0,0,0)");
          gradV.addColorStop(1, "rgba(0,0,0,1)");
          ctx.fillStyle = gradV;
          ctx.fillRect(0, 0, width, height);
        }
      }

      Rectangle {
        width: 16; height: 16; radius: 8;
        border.width: 2;
        border.color: "white";
        color: "transparent";
        x: wheel.sat * svCard.width - width / 2;
        y: (1 - wheel.val) * svCard.height - height / 2;

        layer.enabled: true; // crisp ring over the gradient at any bg brightness
      }

      function _fromPoint(px, py) {
        var x = Math.max(0, Math.min(svCard.width, px));
        var y = Math.max(0, Math.min(svCard.height, py));
        wheel.sat = x / svCard.width;
        wheel.val = 1 - y / svCard.height;
        wheel.changed(wheel.hue, wheel.sat, wheel.val);
      }

      DragHandler {
        target: null;
        onActiveChanged: active ? wheel.dragStarted() : wheel.dragEnded();
        onCentroidChanged: if (active) svCard._fromPoint(centroid.position.x, centroid.position.y);
      }
      TapHandler {
        onTapped: (eventPoint) => svCard._fromPoint(eventPoint.position.x, eventPoint.position.y);
      }
    }

    // --- hue strip ---
    Rectangle {
      id: hueCard;
      width: wheel.svSize; height: wheel.hueBarHeight;
      radius: height / 2;
      border.width: 1;
      border.color: CurrentTheme.border;
      clip: true;

      Canvas {
        anchors.fill: parent;
        Component.onCompleted: requestPaint();
        onPaint: {
          var ctx = getContext("2d");
          ctx.reset();
          var grad = ctx.createLinearGradient(0, 0, width, 0);
          for (var deg = 0; deg <= 360; deg += 60)
            grad.addColorStop(deg / 360, Qt.hsva(deg / 360, 1, 1, 1));
          ctx.fillStyle = grad;
          ctx.fillRect(0, 0, width, height);
        }
      }

      Rectangle {
        width: 6; height: parent.height;
        radius: 3;
        border.width: 2;
        border.color: "white";
        color: "transparent";
        x: (wheel.hue / 360) * (hueCard.width - width);
      }

      function _fromPoint(px) {
        var x = Math.max(0, Math.min(hueCard.width, px));
        wheel.hue = (x / hueCard.width) * 360;
        wheel.changed(wheel.hue, wheel.sat, wheel.val);
      }

      DragHandler {
        target: null;
        onActiveChanged: active ? wheel.dragStarted() : wheel.dragEnded();
        onCentroidChanged: if (active) hueCard._fromPoint(centroid.position.x);
      }
      TapHandler {
        onTapped: (eventPoint) => hueCard._fromPoint(eventPoint.position.x);
      }
    }

    // --- live readout (instant, entirely local — no network round-trip) ---
    Row {
      id: swatchRow;
      spacing: Theme.defaultSpacing;

      Rectangle {
        width: 22; height: 22; radius: 11;
        anchors.verticalCenter: parent.verticalCenter;
        border.width: 1;
        border.color: CurrentTheme.border;
        color: Qt.hsva(wheel.hue / 360, wheel.sat, wheel.val, 1);
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter;
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
        text: Math.round(wheel.hue) + "°  " + Math.round(wheel.sat * 100) + "%  " + Math.round(wheel.val * 100) + "%";
      }
    }
  }
}
