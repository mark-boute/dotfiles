import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.UPower

import qs
import qs.services as Services

// What each lock surface shows (see modules/Lock.qml): the glass sheet
// growing out of the bar's clock pill over a still of the screen, then the
// lock screen — clock, date, now playing, name and password. `unlocking`
// plays the grow back; `authenticated()` fires on a good password.
Item {
  id: surface;

  property var captureScreen: null;
  property bool unlocking: false;
  property string userName: "";
  signal authenticated();


  property bool authing: pam.active;
  property bool wrong: false;       // red ring after a failed attempt
  property string errorText: "";    // only for errors that aren't a wrong password
  property bool capsLock: false;

  readonly property real sw: width;
  readonly property real sh: height;
  readonly property real pillW: 74;
  readonly property real pillH: Theme.barHeight;

  // --- the grow ---
  Spring {
    id: growW;
    to: surface.unlocking || !surface.started ? surface.pillW : surface.sw;
    growPeriod: 0.60;
    shrinkPeriod: 0.45; shrinkDelay: 0.18 + 0.04;
  }
  Spring {
    id: growH;
    to: surface.unlocking || !surface.started ? surface.pillH : surface.sh;
    growPeriod: 0.65; growDelay: 0.04;
    shrinkPeriod: 0.45; shrinkDelay: 0.18;
  }
  // Held at the pill until the surface has its size, then grown.
  property bool started: false;
  Timer { interval: 30; running: surface.sw > 0 && !surface.started; onTriggered: surface.started = true; }
  Component.onCompleted: {
    pw.forceActiveFocus();
    capsProc.running = true;
  }

  readonly property real p: sh > pillH ? Math.max(0, Math.min(1, (growH.value - pillH) / (sh - pillH))) : 1;
  readonly property real cornerR: 16 * Math.max(0, Math.min(1, (1 - p) / 0.25));

  // Lock screen over the glass: in once the grow passes 85%, out first on unlock.
  property real lockOp: 0;
  Behavior on lockOp { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
  Binding {
    target: surface;
    property: "lockOp";
    value: (!surface.unlocking && surface.p >= 0.85) ? 1 : 0;
  }

  Rectangle { anchors.fill: parent; color: CurrentTheme.background; }

  // --- still of the screen at lock time ---
  ScreencopyView {
    id: shot;
    anchors.fill: parent;
    captureSource: surface.captureScreen;
    live: false;
    paintCursor: false;
  }

  // --- the glass sheet: the still, blurred inside the growing shape ---
  Item {
    id: sheetMask;
    anchors.fill: parent;
    layer.enabled: true;
    visible: false;
    Rectangle {
      x: (surface.sw - growW.value) / 2;
      y: -surface.cornerR;
      width: growW.value;
      height: growH.value + surface.cornerR;
      radius: surface.cornerR;
    }
  }
  MultiEffect {
    anchors.fill: parent;
    source: shot;
    autoPaddingEnabled: false;
    blurEnabled: true;
    blur: 1.0;
    blurMax: 64;
    blurMultiplier: 1.4;
    brightness: -0.12;
    saturation: -0.25;
    maskEnabled: true;
    maskSource: sheetMask;
  }
  Rectangle {
    x: (surface.sw - growW.value) / 2;
    y: -surface.cornerR;
    width: growW.value;
    height: growH.value + surface.cornerR;
    radius: surface.cornerR;
    color: CurrentTheme.surface;
  }

  // --- lock screen ---
  Item {
    id: lockScreen;
    anchors.fill: parent;
    opacity: surface.lockOp;
    visible: opacity > 0;

    Image {
      id: wall;
      anchors.fill: parent;
      source: Theme.backgroundImage;
      fillMode: Image.PreserveAspectCrop;
      asynchronous: true;
      visible: false;
    }
    MultiEffect {
      anchors.fill: parent;
      source: wall;
      blurEnabled: true;
      blur: 0.65;
      blurMax: 48;
      brightness: -0.08;
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.28); }

    // --- battery, top right ---
    Row {
      visible: UPower.displayDevice.isLaptopBattery;
      anchors { right: parent.right; top: parent.top; rightMargin: 22; topMargin: 16; }
      height: 20;
      spacing: 8;
      Item {
        anchors.verticalCenter: parent.verticalCenter;
        width: 30; height: 14;
        Rectangle { width: 27; height: 14; radius: 4; color: "transparent"; border.width: 1.5; border.color: Qt.rgba(1, 1, 1, 0.8); }
        Rectangle { x: 28; y: 4; width: 2; height: 6; radius: 1; color: Qt.rgba(1, 1, 1, 0.8); }
        Rectangle { x: 3; y: 3; height: 8; radius: 2; width: Math.max(2, 21 * UPower.displayDevice.percentage); color: "white"; }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter;
        text: Math.round(UPower.displayDevice.percentage * 100) + "%";
        color: "white";
        font.pixelSize: 13; font.weight: Font.Bold;
      }
    }

    // --- date (the clock itself flies in, below) ---
    Text {
      anchors.horizontalCenter: parent.horizontalCenter;
      y: surface.sh / 2 - 108;
      text: Services.SystemClock.weekday + ", " + Services.SystemClock.date;
      color: Qt.rgba(1, 1, 1, 0.75);
      font.pixelSize: 17;
    }

    // --- now playing ---
    Rectangle {
      visible: Services.MediaService.hasPlayer && Services.MediaService.title !== "";
      anchors.horizontalCenter: parent.horizontalCenter;
      y: surface.sh / 2 - 64;
      width: 300; height: 48; radius: 24;
      color: Qt.rgba(0, 0, 0, 0.28);

      Row {
        anchors.fill: parent;
        anchors.leftMargin: 8;
        anchors.rightMargin: 8;
        spacing: 10;

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter;
          width: 32; height: 32; radius: 8;
          color: Qt.rgba(1, 1, 1, 0.12);
          clip: true;
          Image {
            anchors.fill: parent;
            source: Services.MediaService.artUrl;
            fillMode: Image.PreserveAspectCrop;
            asynchronous: true;
            visible: status === Image.Ready;
          }
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter;
          width: parent.width - 32 - 32 - 20;
          spacing: 1;
          Text {
            width: parent.width;
            text: Services.MediaService.title;
            elide: Text.ElideRight;
            color: "white";
            font.pixelSize: 12; font.weight: Font.Bold;
          }
          Text {
            width: parent.width;
            visible: text !== "";
            text: Services.MediaService.artist;
            elide: Text.ElideRight;
            color: Qt.rgba(1, 1, 1, 0.7);
            font.pixelSize: 11;
          }
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter;
          width: 32; height: 32; radius: 16;
          color: playHover.hovered ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.16);
          Text {
            anchors.centerIn: parent;
            text: String.fromCodePoint(Services.MediaService.playing ? 0xf03e4 : 0xf040a); // md-pause / md-play
            font.family: Theme.iconFontFamily;
            font.pixelSize: 16;
            color: "white";
          }
          HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor; }
          TapHandler { onTapped: { Services.MediaService.togglePlaying(); pw.forceActiveFocus(); } }
        }
      }
    }

    // --- who, and the password ---
    Text {
      anchors.horizontalCenter: parent.horizontalCenter;
      y: surface.sh / 2 + 36;
      text: surface.userName;
      color: "white";
      font.pixelSize: 16; font.weight: Font.Bold;
    }

    Rectangle {
      id: field;
      anchors.horizontalCenter: parent.horizontalCenter;
      y: surface.sh / 2 + 66;
      width: 340;
      height: 46;
      radius: 23;
      color: Qt.rgba(0, 0, 0, 0.35);
      border.width: surface.wrong ? 2 : 1;
      border.color: surface.wrong ? CurrentTheme.danger
        : pw.activeFocus ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.18);
      Behavior on border.color { ColorAnimation { duration: 300 } }

      property real shakeX: 0;
      transform: Translate { x: field.shakeX }
      // 420ms, easing out like cubic-bezier(0.36, 0.07, 0.19, 0.97).
      SequentialAnimation {
        id: shake;
        NumberAnimation { target: field; property: "shakeX"; to: -10; duration: 63; easing.type: Easing.OutCubic }
        NumberAnimation { target: field; property: "shakeX"; to: 9;   duration: 63; easing.type: Easing.InOutCubic }
        NumberAnimation { target: field; property: "shakeX"; to: -7;  duration: 63; easing.type: Easing.InOutCubic }
        NumberAnimation { target: field; property: "shakeX"; to: 5;   duration: 63; easing.type: Easing.InOutCubic }
        NumberAnimation { target: field; property: "shakeX"; to: -3;  duration: 63; easing.type: Easing.InOutCubic }
        NumberAnimation { target: field; property: "shakeX"; to: 1;   duration: 63; easing.type: Easing.InOutCubic }
        NumberAnimation { target: field; property: "shakeX"; to: 0;   duration: 42; easing.type: Easing.OutCubic }
      }
      Timer { id: wrongTimer; interval: 1200; onTriggered: surface.wrong = false; }
      function reject() {
        surface.wrong = true;
        wrongTimer.restart();
        shake.restart();
      }

      Text {
        anchors.centerIn: parent;
        visible: pw.text === "" && !surface.authing;
        text: "Password";
        color: Qt.rgba(1, 1, 1, 0.6);
        font.pixelSize: 15;
      }

      Row {
        anchors.centerIn: parent;
        spacing: 9;
        visible: pw.text !== "" && !surface.authing;
        Repeater {
          model: Math.min(pw.text.length, 16);
          Rectangle { width: 8; height: 8; radius: 4; color: "white"; }
        }
      }

      Text {
        anchors.centerIn: parent;
        visible: surface.authing;
        text: "Checking…";
        color: Qt.rgba(1, 1, 1, 0.7);
        font.pixelSize: 13;
      }

      TextInput {
        id: pw;
        anchors.fill: parent;
        opacity: 0;               // invisible; the dots row is the display
        focus: true;
        enabled: !surface.authing && !surface.unlocking;
        echoMode: TextInput.Password;
        activeFocusOnTab: true;
        onTextChanged: { surface.errorText = ""; }
        onAccepted: {
          if (pw.text.length > 0 && !surface.authing)
            pam.start();
        }
        Keys.onPressed: (e) => { if (e.key === Qt.Key_CapsLock) capsDelay.restart(); }
      }
    }

    // Caps Lock hint, or an error that isn't just a wrong password.
    Row {
      anchors.horizontalCenter: parent.horizontalCenter;
      y: surface.sh / 2 + 122;
      height: 18;
      spacing: 6;
      opacity: surface.capsLock || surface.errorText !== "" ? 1 : 0;
      Behavior on opacity { NumberAnimation { duration: 150 } }
      Text {
        anchors.verticalCenter: parent.verticalCenter;
        visible: surface.errorText === "";
        text: String.fromCodePoint(0xf0632); // md-apple-keyboard-caps
        font.family: Theme.iconFontFamily;
        font.pixelSize: 14;
        color: Qt.rgba(1, 1, 1, 0.85);
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter;
        text: surface.errorText !== "" ? surface.errorText : "Caps Lock is on";
        color: surface.errorText !== "" ? CurrentTheme.danger : Qt.rgba(1, 1, 1, 0.85);
        font.pixelSize: 12;
      }
    }
  }

  // --- the clock: flies from the bar pill into the lock clock ---
  Item {
    id: flyClock;
    readonly property real t: Math.max(0, Math.min(1, surface.p));
    readonly property real fromY: surface.pillH / 2;
    readonly property real toY: surface.sh / 2 - 166;
    readonly property real k: 14 / 108 + (1 - 14 / 108) * t;
    x: surface.sw / 2;
    y: fromY + (toY - fromY) * t;
    scale: k;

    Text {
      anchors.centerIn: parent;
      text: Services.SystemClock.time;
      color: CurrentTheme.accent;
      font.pixelSize: 108; font.weight: Font.Bold;
      opacity: 1 - Math.max(0, Math.min(1, (flyClock.t - 0.2) / 0.5));
    }
    Text {
      anchors.centerIn: parent;
      text: Services.SystemClock.time;
      color: "white";
      font.pixelSize: 108; font.weight: Font.ExtraLight;
      opacity: Math.max(0, Math.min(1, (flyClock.t - 0.2) / 0.5));
    }
  }

  Connections {
    target: surface;
    function onAuthingChanged() { if (!surface.authing) pw.forceActiveFocus(); }
  }

  // --- Caps Lock state (Hyprland knows it; Qt doesn't) ---
  Timer { id: capsDelay; interval: 80; onTriggered: capsProc.running = true; }
  Process {
    id: capsProc;
    command: ["hyprctl", "devices", "-j"];
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var kbs = JSON.parse((typeof this.text === "function") ? this.text() : this.text).keyboards || [];
          var main = kbs.filter(k => k.main)[0] || kbs[0];
          surface.capsLock = !!(main && main.capsLock);
        } catch (e) {}
      }
    }
  }

  PamContext {
    id: pam;
    config: "swaylock";

    onPamMessage: {
      if (pam.messageIsError)
        surface.errorText = pam.message;
      else if (pam.responseRequired)
        pam.respond(pw.text);
    }
    onError: (err) => {
      surface.errorText = "Authentication error";
      pw.text = "";
      field.reject();
    }
    onCompleted: (result) => {
      pw.text = "";
      if (result === PamResult.Success) {
        surface.wrong = false;
        surface.authenticated();
        return;
      }
      if (result === PamResult.MaxTries)
        surface.errorText = "Too many attempts";
      field.reject();
    }
  }
}
