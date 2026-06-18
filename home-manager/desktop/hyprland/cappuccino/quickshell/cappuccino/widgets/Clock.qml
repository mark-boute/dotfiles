import Quickshell
import QtQuick

import qs
import qs.shapes as Shapes
import qs.services as Services

Shapes.MenuPill {
  id: clockWidget;

  property string displayText: Services.SystemClock.time;

  // textMeasurer (invisible) drives the pill width immediately on hover so the
  // expand animation starts right away, while clockText only swaps near the end.
  implicitWidth: textMeasurer.implicitWidth + Theme.defaultMargin * 2;

  Behavior on implicitWidth {
    NumberAnimation {
      duration: mouse.hovered ? 160 : 80;
      easing.type: Easing.OutExpo;
    }
  }

  Text {
    id: textMeasurer;
    visible: false;
    text: mouse.hovered ? Services.SystemClock.datetime : Services.SystemClock.time;
    font.pixelSize: 15;
    font.weight: Font.Medium;
  }

  Text {
    id: clockText;
    anchors.centerIn: parent;
    color: Theme.current.rosewater;
    font.pixelSize: 15;
    font.weight: Font.Medium;
    text: clockWidget.displayText;
    // Translate lets us slide the text without fighting anchors.centerIn
    transform: Translate { id: textSlide; x: 0 }
  }

  HoverHandler {
    id: mouse;
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad;
    onHoveredChanged: {
      if (mouse.hovered) {
        textSwapTimer.restart();
      } else {
        // Collapse: revert text immediately, fade it back in (no slide — pill shrinks inward)
        textSwapTimer.stop();
        minuteTickAnim.stop();
        textAppearAnim.stop();
        clockWidget.displayText = Services.SystemClock.time;
        clockText.opacity = 0;
        textAppearAnim.start();
      }
    }
  }

  // Fires at ~85% through the 160ms expand — pill is nearly fully open.
  Timer {
    id: textSwapTimer;
    interval: 135;
    onTriggered: {
      minuteTickAnim.stop();
      textAppearAnim.stop();
      // Slide datetime in from the right: the pill just expanded that direction.
      textSlide.x = 8;
      clockText.opacity = 0;
      clockWidget.displayText = Services.SystemClock.datetime;
      textAppearAnim.start();
    }
  }

  // Shared appear animation: fade in + slide x offset back to 0.
  // For collapse the offset is already 0, so it just fades.
  ParallelAnimation {
    id: textAppearAnim;
    NumberAnimation { target: clockText;  property: "opacity"; to: 1; duration: 120; easing.type: Easing.OutCubic }
    NumberAnimation { target: textSlide;  property: "x";       to: 0; duration: 150; easing.type: Easing.OutCubic }
  }

  // Minute tick: fade out → swap text → fade back in.
  SequentialAnimation {
    id: minuteTickAnim;
    NumberAnimation { target: clockText; property: "opacity"; to: 0;  duration: 80;  easing.type: Easing.OutCubic }
    ScriptAction    { script: clockWidget.displayText = mouse.hovered ? Services.SystemClock.datetime : Services.SystemClock.time; }
    NumberAnimation { target: clockText; property: "opacity"; to: 1;  duration: 150; easing.type: Easing.OutCubic }
  }

  // Keep displayText accurate on every minute tick.
  Connections {
    target: Services.SystemClock;
    function onTimeChanged() {
      if (!textSwapTimer.running) {
        minuteTickAnim.restart();
      }
    }
  }
}
