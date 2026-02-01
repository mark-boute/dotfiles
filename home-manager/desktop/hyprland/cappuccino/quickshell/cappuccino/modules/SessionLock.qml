import Quickshell;
import QtQuick;
import Quickshell.Wayland;
import QtQuick.Shapes;
import Quickshell.Services.Pam;
import qs;

WlSessionLock {
  id: sessionLock;
  property string currentInput: "";
  property string feedbackMessage: ""; // To store PAM messages

  WlSessionLockSurface {
    id: surface;

    PamContext {
      id: pam;

      onPamMessage: {
        if (pam.messageIsError) {
          feedbackMessage = pam.message;
          shakeAnimation.start();
          currentInput = "";
        } else if (pam.responseRequired) {
          pam.respond(currentInput);
        }
      }

      onError: (error) => {
        // Handle system-level PAM errors (e.g., config issues)
        feedbackMessage = "System Error: " + PamError.toString(error);
        shakeAnimation.start();
        currentInput = "";
      }

      onCompleted: (result) => {
        currentInput = "";

        if (result === PamResult.Success) {
          sessionLock.locked = false;
          return
        } 
        
        else if (result === PamResult.MaxTries) {
          feedbackMessage = "Maximum attempts reached.";
        } else if (result === PamResult.Failed) {
          feedbackMessage = "Incorrect";
        } else if (result === PamResult.Error) {
          feedbackMessage = "Authentication Error.";
        } else {
          feedbackMessage = "Unknown result state.";
        }

        shakeAnimation.start();
      }
    }

    Rectangle {
      id: content;
      anchors.fill: parent;
      color: Theme.backgroundColor;
      focus: true;

      Timer {
        id: idleTimer;
        interval: 3000;
        running: true;
        repeat: false;
        onTriggered: content.state = "dimmed";
      }

      Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
          content.state = "dimmed";
          currentInput = "";
          feedbackMessage = "";
          idleTimer.restart();
          return;
        }

        if (content.state !== "input") {
          content.state = "input";
          idleTimer.stop();
        }

        if (feedbackMessage !== "") feedbackMessage = "";
        
        if (event.text >= "0" && event.text <= "9") {
          if (currentInput.length < 4) {
            currentInput += event.text;
            if (currentInput.length === 4) pam.start();
          }
        } else if (event.key === Qt.Key_Backspace) {
          currentInput = currentInput.substring(0, currentInput.length - 1);
        }
      }

      // --- Layout ---
      Row {
        id: dimmedLayout;
        anchors.centerIn: parent;
        spacing: 40;

        Text {
          id: leftText;
          text: "On a";
          // Use dot notation for font properties
          font.pixelSize: 64;
          font.weight: Font.Bold;
          font.family: "JetBrains Mono";
          color: Theme.current.subtext0;
          opacity: 0;
          anchors.verticalCenter: parent.verticalCenter;
        }

        Image {
          id: bg;
          width: (content.width / 4 + content.height / 2) * 0.35;
          source: "/home/mark/dotfiles/home-manager/desktop/hyprland/cappuccino/assets/coffee_pixel.png";
          fillMode: Image.PreserveAspectFit;
          smooth: false;
          opacity: 1.0;
          anchors.verticalCenter: parent.verticalCenter;
        }

        Text {
          id: rightText;
          text: "break";
          font.pixelSize: 64;
          font.weight: Font.Bold;
          font.family: "JetBrains Mono";
          color: Theme.current.subtext0;
          opacity: 0;
          anchors.verticalCenter: parent.verticalCenter;
        }
      }

      // PIN Entry Column
      Column {
        id: pinColumn;
        anchors.centerIn: parent;
        spacing: 0;
        opacity: content.state === "input" ? 1 : 0;
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Rectangle {
          id: pinContainer;
          // Dynamically adjust height if there's a message
          width: pinDisplay.width + 40;
          height: (feedbackMessage !== "") ? pinDisplay.height + 80 : pinDisplay.height + 30;
          radius: 15;
          clip: true; // Keeps the text hidden until the height expands
          
          color: Qt.rgba(Theme.current.surface0.r, Theme.current.surface0.g, Theme.current.surface0.b, 0.8); // Higher opacity for readability
          border.color: Qt.rgba(Theme.current.text.r, Theme.current.text.g, Theme.current.text.b, 0.1);
          border.width: 1;

          Behavior on height {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
          }

          Shape {
            id: loaderShape;
            anchors.fill: parent;
            anchors.margins: -1;
            visible: pam.active;
            layer.enabled: true;
            layer.samples: 4;
            property real totalLength: (2 * (width - 30)) + (2 * (height - 30)) + (2 * Math.PI * 15);

            ShapePath {
              strokeWidth: 2; strokeColor: Theme.current.rosewater;
              fillColor: "transparent"; capStyle: ShapePath.RoundCap;
              strokeStyle: ShapePath.DashLine;
              dashPattern: [loaderShape.totalLength / 3, (loaderShape.totalLength / 3) * 2];
              
              startX: 15; startY: 0;
              PathLine { x: pinContainer.width - 15; y: 0 }
              PathArc { x: pinContainer.width; y: 15; radiusX: 15; radiusY: 15 }
              PathLine { x: pinContainer.width; y: pinContainer.height - 15 }
              PathArc { x: pinContainer.width - 15; y: pinContainer.height; radiusX: 15; radiusY: 15 }
              PathLine { x: 15; y: pinContainer.height }
              PathArc { x: 0; y: pinContainer.height - 15; radiusX: 15; radiusY: 15 }
              PathLine { x: 0; y: 15 }
              PathArc { x: 15; y: 0; radiusX: 15; radiusY: 15 }

              NumberAnimation on dashOffset {
                from: 0; to: -loaderShape.totalLength;
                duration: 1333; loops: Animation.Infinite; running: pam.active;
              }
            }
          }

          // Dots and Text
          Column {
            anchors.centerIn: parent;
            spacing: 15;

            Row {
              id: pinDisplay;
              anchors.horizontalCenter: parent.horizontalCenter;
              spacing: 20;
              Repeater {
                model: 4;
                Rectangle {
                  width: 20; height: 20; radius: 10;
                  color: index < currentInput.length ? Theme.current.rosewater : Theme.current.surface2;
                  border.color: Theme.current.text; border.width: 1;
                }
              }
            }

            Text {
              id: statusText;
              text: feedbackMessage;
              font: { pixelSize: 14; weight: Font.Medium; family: "JetBrains Mono" }
              color: Theme.current.red; // Or Theme.current.text for more subtleness
              anchors.horizontalCenter: parent.horizontalCenter;
              opacity: feedbackMessage !== "" ? 1 : 0;
              Behavior on opacity { NumberAnimation { duration: 200 } }
            }
          }
        }
      }

      SequentialAnimation {
        id: shakeAnimation;
        NumberAnimation { target: pinContainer; property: "anchors.horizontalCenterOffset"; from: 0; to: 20; duration: 50; }
        NumberAnimation { target: pinContainer; property: "anchors.horizontalCenterOffset"; from: 20; to: -20; duration: 50; }
        NumberAnimation { target: pinContainer; property: "anchors.horizontalCenterOffset"; from: -20; to: 20; duration: 50; }
        NumberAnimation { target: pinContainer; property: "anchors.horizontalCenterOffset"; from: 20; to: -20; duration: 50; }
        NumberAnimation { target: pinContainer; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50; }
      }

      states: [
        State {
          name: "dimmed";
          PropertyChanges { target: content; color: Theme.macchiato.crust }
          PropertyChanges { target: bg; opacity: 0.2 }
          PropertyChanges { target: leftText; opacity: 0.25 }
          PropertyChanges { target: rightText; opacity: 0.25 }
        },
        State {
          name: "input";
          PropertyChanges { target: content; color: Theme.backgroundColor }
          PropertyChanges { target: dimmedLayout; anchors.verticalCenterOffset: -content.height / 4 }
          PropertyChanges { target: bg; opacity: 1.0 }
          PropertyChanges { target: leftText; opacity: 0 }
          PropertyChanges { target: rightText; opacity: 0 }
        }
      ]

      transitions: [
        // Instant exit when moving from input back to dimmed (Escape key)
        Transition {
          from: "input"; to: "dimmed";
          NumberAnimation { 
            target: pinColumn; 
            property: "opacity"; 
            duration: 0 
          }
          // The rest of the screen can still fade slowly over 10s
          ColorAnimation { duration: 10000 }
          NumberAnimation { 
            targets: [bg, leftText, rightText]; 
            property: "opacity"; 
            duration: 10000 
          }
        },
        // Smooth entrance when going to input
        Transition {
          from: "*"; to: "input";
          ColorAnimation { duration: 300 }
          NumberAnimation { 
            properties: "anchors.verticalCenterOffset,opacity"; 
            duration: 400; 
            easing.type: Easing.OutExpo 
          }
        },
        // Default dimmed transition
        Transition {
          from: "input"; to: "dimmed";
          ColorAnimation { duration: 10000 }
          NumberAnimation { properties: "opacity"; duration: 10000 }
        }
      ]
    }
  }
}