import QtQuick
import Quickshell
import Quickshell.Wayland

import qs
import qs.services as Services

// Wallpaper, on the Background layer (behind everything, including normal
// windows). Tracks Theme.backgroundImage, which follows Theme.flavor — so
// picking a new theme in the control panel swaps the sky. Two stacked
// Image layers crossfade between old/new instead of popping instantly.
PanelWindow {
  id: bg;
  required property var modelData;
  screen: modelData;

  // Bottom rather than Background: still behind every normal window, but
  // this currently needs to outrank cappuccino's own wallpaper window too
  // (running side by side for testing) — cappuccino's doesn't set an
  // explicit layer, which resolves one level above plain Background.
  WlrLayershell.layer: WlrLayer.Bottom;
  WlrLayershell.namespace: "quickshell:resonate:background";
  exclusionMode: ExclusionMode.Ignore;

  anchors { top: true; left: true; right: true; bottom: true; }
  color: CurrentTheme.background;

  property bool topIsA: true;

  // Background is instantiated for every screen at startup; the drawer's
  // ThemeApp is not. Referencing ThemeService here is what keeps its
  // sun-phase timer (and the auto flavour/wallpaper switching) actually
  // running whether or not the panel has ever been opened.
  readonly property var themeService: Services.ThemeService;

  Image {
    id: layerA;
    anchors.fill: parent;
    fillMode: Image.PreserveAspectCrop;
    asynchronous: true;
    opacity: bg.topIsA ? 1 : 0;
    Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
  }

  Image {
    id: layerB;
    anchors.fill: parent;
    fillMode: Image.PreserveAspectCrop;
    asynchronous: true;
    opacity: bg.topIsA ? 0 : 1;
    Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
  }

  Component.onCompleted: layerA.source = Theme.backgroundImage;

  Connections {
    target: Theme;
    function onBackgroundImageChanged() {
      if (bg.topIsA) {
        layerB.source = Theme.backgroundImage;
      } else {
        layerA.source = Theme.backgroundImage;
      }
      bg.topIsA = !bg.topIsA;
    }
  }
}
