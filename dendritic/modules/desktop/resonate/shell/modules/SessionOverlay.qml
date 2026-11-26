import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs
import qs.services as Services

// Power off / restart / log out shortcuts (quickshell:Session* globals, bound
// in hypr/keybinds.lua) and the dim behind their confirm. The confirm itself
// grows out of the focused screen's power pill (SessionConfirm in
// SystemPanel); this dim sits on the Top layer, under the Overlay-layer bar,
// so the bar never depends on same-layer stacking order. Clicking the dim
// cancels.
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
      visible: scope.active || dim.opacity > 0;

      WlrLayershell.layer: WlrLayer.Top;
      WlrLayershell.namespace: "quickshell:resonate:session";
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None;
      exclusionMode: ExclusionMode.Ignore;

      anchors { top: true; bottom: true; left: true; right: true; }
      color: "transparent";

      Rectangle {
        id: dim;
        anchors.fill: parent;
        color: "black";
        opacity: scope.active ? 0.5 : 0;
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: Services.SessionService.cancel(); }
      }
    }
  }
}
