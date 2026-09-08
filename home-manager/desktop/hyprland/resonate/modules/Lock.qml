import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam

import qs
import qs.services as Services

// Session lock. Triggered by the `quickshell:Lock` global (SUPER+Escape and
// hypridle's lock_cmd). Auth via PAM (/etc/pam.d/swaylock — plain pam_unix,
// unprivileged). On appear it shows a heavy blur of whatever was on screen
// (unreadable) with the wallpaper fading in over it.
Scope {
  id: scope;

  property bool locked: false;

  GlobalShortcut {
    appid: "quickshell";
    name: "Lock";
    onPressed: scope.locked = true;
  }

  WlSessionLock {
    id: lock;
    locked: scope.locked;

    WlSessionLockSurface {
      id: surface;
      color: CurrentTheme.background;

      property string errorText: "";
      property bool authing: pam.active;

      Rectangle { anchors.fill: parent; color: CurrentTheme.background; }

      // --- frozen, heavily blurred capture of the screen at lock time ---
      ScreencopyView {
        id: shot;
        anchors.fill: parent;
        captureSource: surface.screen;
        live: false;
        paintCursor: false;
        visible: false;
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
      }

      // --- wallpaper, blurred, fading in on top ---
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
        opacity: 0;
        NumberAnimation on opacity {
          from: 0; to: 1; duration: 900; running: true;
          easing.type: Easing.OutCubic;
        }
      }

      Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.28); }

      // --- clock ---
      Column {
        anchors.horizontalCenter: parent.horizontalCenter;
        anchors.verticalCenter: parent.verticalCenter;
        anchors.verticalCenterOffset: -parent.height * 0.14;
        spacing: 4;

        Text {
          anchors.horizontalCenter: parent.horizontalCenter;
          text: Services.SystemClock.time;
          color: "white";
          font.pixelSize: 108;
          font.weight: Font.Thin;
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter;
          text: Services.SystemClock.weekday + ", " + Services.SystemClock.date;
          color: Qt.rgba(1, 1, 1, 0.75);
          font.pixelSize: 17;
          font.weight: Font.Medium;
        }
      }

      // --- password ---
      Column {
        id: authCol;
        anchors.horizontalCenter: parent.horizontalCenter;
        anchors.verticalCenter: parent.verticalCenter;
        anchors.verticalCenterOffset: parent.height * 0.16;
        spacing: 12;

        Rectangle {
          id: field;
          anchors.horizontalCenter: parent.horizontalCenter;
          width: 340;
          height: 46;
          radius: 23;
          color: Qt.rgba(0, 0, 0, 0.35);
          border.width: 1;
          border.color: pw.activeFocus ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.18);

          Behavior on border.color { ColorAnimation { duration: 120 } }

          property real shakeX: 0;
          transform: Translate { x: field.shakeX }
          SequentialAnimation {
            id: shake;
            loops: 1;
            NumberAnimation { target: field; property: "shakeX"; to: 14; duration: 45 }
            NumberAnimation { target: field; property: "shakeX"; to: -14; duration: 45 }
            NumberAnimation { target: field; property: "shakeX"; to: 9; duration: 45 }
            NumberAnimation { target: field; property: "shakeX"; to: 0; duration: 45 }
          }

          Text {
            anchors.centerIn: parent;
            visible: pw.text === "" && !surface.authing;
            text: "Enter password";
            color: Qt.rgba(1, 1, 1, 0.5);
            font.pixelSize: 13;
          }

          // dots
          Row {
            anchors.centerIn: parent;
            spacing: 9;
            visible: pw.text !== "" && !surface.authing;
            Repeater {
              model: Math.min(pw.text.length, 12);
              Rectangle { width: 8; height: 8; radius: 4; color: "white"; }
            }
          }

          // spinner while authing
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
            enabled: !surface.authing;
            echoMode: TextInput.Password;
            activeFocusOnTab: true;
            onTextChanged: surface.errorText = "";
            onAccepted: {
              if (pw.text.length > 0 && !surface.authing)
                pam.start();
            }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter;
          text: surface.errorText;
          color: CurrentTheme.danger;
          font.pixelSize: 12;
          font.weight: Font.Medium;
          opacity: surface.errorText !== "" ? 1 : 0;
          Behavior on opacity { NumberAnimation { duration: 150 } }
        }
      }

      // keep the field focused
      Component.onCompleted: pw.forceActiveFocus();
      Connections {
        target: surface;
        function onAuthingChanged() { if (!surface.authing) pw.forceActiveFocus(); }
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
          shake.start();
        }
        onCompleted: (result) => {
          pw.text = "";
          if (result === PamResult.Success) {
            scope.locked = false;
            return;
          }
          surface.errorText = result === PamResult.MaxTries
            ? "Too many attempts" : "Incorrect password";
          shake.start();
        }
      }
    }
  }
}
