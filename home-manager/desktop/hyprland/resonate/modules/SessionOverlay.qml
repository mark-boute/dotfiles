import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs
import qs.services as Services

// Fullscreen confirm for power off / restart / log out. Opened by the
// quickshell:SessionPoweroff / :SessionReboot / :SessionLogout globals
// (bound to the keybinds in hypr/keybinds.lua). Confirm is preselected, so
// the flow is: hit the shortcut, hit Enter. Left/Right (or Tab) move between
// Confirm and Cancel; Esc or a click outside dismisses. SessionService runs
// the actual command — nothing closes before Confirm.
Scope {
  id: scope;

  readonly property bool active: Services.SessionService.pending !== "";

  GlobalShortcut { appid: "quickshell"; name: "SessionPoweroff"; onPressed: Services.SessionService.request("poweroff"); }
  GlobalShortcut { appid: "quickshell"; name: "SessionReboot";   onPressed: Services.SessionService.request("reboot"); }
  GlobalShortcut { appid: "quickshell"; name: "SessionLogout";   onPressed: Services.SessionService.request("logout"); }

  Variants {
    model: Quickshell.screens;

    delegate: PanelWindow {
      id: win;
      required property var modelData;
      screen: modelData;
      visible: scope.active;

      WlrLayershell.layer: WlrLayer.Overlay;
      WlrLayershell.namespace: "quickshell:resonate:session";
      // Only the surface on the focused monitor takes the keyboard — the
      // others just dim.
      WlrLayershell.keyboardFocus: (scope.active && win.onFocusedScreen)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;

      readonly property bool onFocusedScreen: {
        var m = Hyprland.monitorFor(win.screen);
        return m ? m.focused : true;
      }

      anchors { top: true; bottom: true; left: true; right: true; }
      color: "transparent";

      // Grab focus once the surface is actually up. Deferred + retried
      // because the layer surface isn't focusable the instant `visible`
      // flips.
      function grab() {
        if (scope.active && win.onFocusedScreen)
          keys.forceActiveFocus();
      }
      onVisibleChanged: { Qt.callLater(win.grab); grabRetry.restart(); }
      Timer {
        id: grabRetry;
        interval: 40; repeat: true; triggeredOnStart: true;
        property int left: 6;
        onTriggered: {
          win.grab();
          if (!scope.active || keys.activeFocus || --left <= 0) { left = 6; stop(); }
        }
      }
      Connections {
        target: Services.SessionService;
        function onPendingChanged() {
          if (Services.SessionService.pending !== "") {
            keys.selection = "confirm";
            Qt.callLater(win.grab);
            grabRetry.restart();
          }
        }
      }

      // Backdrop — click anywhere off the card to dismiss.
      Rectangle {
        anchors.fill: parent;
        color: Qt.rgba(0, 0, 0, 0.5);
        opacity: scope.active ? 1 : 0;
        Behavior on opacity { NumberAnimation { duration: 140 } }

        MouseArea { anchors.fill: parent; onClicked: Services.SessionService.cancel(); }
      }

      Item {
        id: keys;
        anchors.fill: parent;
        focus: true;

        // "confirm" | "cancel" — reset to confirm every time the sheet opens.
        property string selection: "confirm";
        function activate() {
          if (keys.selection === "cancel") Services.SessionService.cancel();
          else Services.SessionService.confirm();
        }
        function swap() {
          keys.selection = (keys.selection === "confirm" ? "cancel" : "confirm");
        }

        Keys.priority: Keys.BeforeItem;
        Keys.onPressed: (e) => {
          switch (e.key) {
          case Qt.Key_Escape:  Services.SessionService.cancel(); break;
          case Qt.Key_Return:
          case Qt.Key_Enter:
          case Qt.Key_Space:   keys.activate(); break;
          case Qt.Key_Left:
          case Qt.Key_Up:      keys.selection = "cancel"; break;   // Cancel is the left button
          case Qt.Key_Right:
          case Qt.Key_Down:    keys.selection = "confirm"; break;   // Confirm is the right button
          case Qt.Key_Tab:
          case Qt.Key_Backtab: keys.swap(); break;
          default: e.accepted = false; return;
          }
          e.accepted = true;
        }

        Rectangle {
          id: dialog;
          anchors.centerIn: parent;
          width: Math.min(430, parent.width - 80);
          implicitHeight: card.implicitHeight + 44;
          radius: 18;
          color: CurrentTheme.surface;
          border.width: 1;
          border.color: CurrentTheme.border;

          opacity: scope.active ? 1 : 0;
          scale: scope.active ? 1 : 0.96;
          Behavior on opacity { NumberAnimation { duration: 140 } }
          Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

          // Swallow clicks on the card so they don't reach the backdrop.
          MouseArea { anchors.fill: parent; }

          ColumnLayout {
            id: card;
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22; }
            spacing: 14;

            RowLayout {
              Layout.fillWidth: true;
              spacing: 13;

              Text {
                text: Services.SessionService.def ? String.fromCodePoint(Services.SessionService.def.glyph) : "";
                font.family: Theme.iconFontFamily;
                font.pixelSize: 26;
                color: (Services.SessionService.def && Services.SessionService.def.danger)
                  ? CurrentTheme.danger : CurrentTheme.text;
              }

              ColumnLayout {
                Layout.fillWidth: true;
                spacing: 2;

                Text {
                  text: Services.SessionService.def ? Services.SessionService.def.title + "?" : "";
                  color: CurrentTheme.text;
                  font.pixelSize: 18;
                  font.weight: Font.DemiBold;
                }
                Text {
                  Layout.fillWidth: true;
                  text: Services.SessionService.pending === "logout"
                    ? "Ends your session and closes every open app."
                    : "Closes every open app on this machine.";
                  color: CurrentTheme.subtext;
                  font.pixelSize: 12;
                  wrapMode: Text.WordWrap;
                }
              }
            }

            // Unsaved-work warning — only when the title scan found something.
            Rectangle {
              Layout.fillWidth: true;
              visible: Services.SessionService.dirty.length > 0;
              implicitHeight: visible ? dirtyCol.implicitHeight + 20 : 0;
              radius: 10;
              color: Qt.rgba(CurrentTheme.warning.r, CurrentTheme.warning.g, CurrentTheme.warning.b, 0.12);
              border.width: 1;
              border.color: Qt.rgba(CurrentTheme.warning.r, CurrentTheme.warning.g, CurrentTheme.warning.b, 0.4);

              ColumnLayout {
                id: dirtyCol;
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; }
                spacing: 5;

                Text {
                  text: "Possibly unsaved work";
                  color: CurrentTheme.warning;
                  font.pixelSize: 12;
                  font.weight: Font.DemiBold;
                }

                Repeater {
                  model: Services.SessionService.dirty;
                  delegate: RowLayout {
                    required property var modelData;
                    Layout.fillWidth: true;
                    spacing: 6;

                    Text { text: "•"; color: CurrentTheme.subtext; font.pixelSize: 12; }
                    Text {
                      Layout.fillWidth: true;
                      text: modelData.title;
                      color: CurrentTheme.text;
                      font.pixelSize: 12;
                      elide: Text.ElideRight;
                    }
                  }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true;
              Layout.topMargin: 2;
              spacing: 10;

              Rectangle {
                Layout.fillWidth: true;
                implicitHeight: 40;
                radius: 10;
                readonly property bool sel: keys.selection === "cancel";
                color: sel ? CurrentTheme.surfaceHover : "transparent";
                border.width: sel ? 2 : 1;
                border.color: sel ? CurrentTheme.accent : CurrentTheme.border;
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                  anchors.centerIn: parent;
                  text: "Cancel";
                  color: CurrentTheme.text;
                  font.pixelSize: 13;
                  font.weight: Font.Medium;
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) keys.selection = "cancel"; }
                TapHandler { onTapped: Services.SessionService.cancel(); }
              }

              Rectangle {
                id: confirmBtn;
                Layout.fillWidth: true;
                implicitHeight: 40;
                radius: 10;
                readonly property bool sel: keys.selection === "confirm";
                readonly property color base: (Services.SessionService.def && Services.SessionService.def.danger)
                  ? CurrentTheme.danger : CurrentTheme.accent;
                color: sel ? base : Qt.rgba(base.r, base.g, base.b, 0.18);
                border.width: sel ? 2 : 0;
                border.color: Qt.lighter(base, 1.3);
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                  anchors.centerIn: parent;
                  text: Services.SessionService.def ? Services.SessionService.def.verb : "";
                  color: confirmBtn.sel ? CurrentTheme.background : confirmBtn.base;
                  font.pixelSize: 13;
                  font.weight: Font.DemiBold;
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) keys.selection = "confirm"; }
                TapHandler { onTapped: Services.SessionService.confirm(); }
              }
            }

            Text {
              Layout.fillWidth: true;
              horizontalAlignment: Text.AlignHCenter;
              text: "Enter · " + (keys.selection === "cancel" ? "Cancel"
                : (Services.SessionService.def ? Services.SessionService.def.verb : ""))
                + "      ←/→ · switch      Esc · dismiss";
              color: CurrentTheme.subtext;
              font.pixelSize: 10;
            }
          }
        }
      }
    }
  }
}
