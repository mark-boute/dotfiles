pragma Singleton

import Quickshell
import QtQuick

Singleton {
  // readonly property SystemPalette colors: SystemPalette { colorGroup: SystemPalette.Active; }


  id: theme;

  readonly property int barHeight: 30;
  readonly property int barVerticalMargin: 5;
  readonly property int barHorizontalMargin: 5;
  readonly property color barColor: "transparent";

  readonly property int defaultMargin: 10;
  readonly property int defaultSpacing: 5;


  readonly property var latte: QtObject {

    readonly property color rosewater: "#dc8a78";
    readonly property color flamingo: "#dd7878";
    readonly property color pink: "#ea76cb";
    readonly property color mauve: "#8839ef";
    readonly property color red: "#d20f39";
    readonly property color maroon: "#e64553";
    readonly property color peach: "#fe640b";
    readonly property color yellow: "#df8e1d";
    readonly property color green: "#40a02b";
    readonly property color teal: "#179299";
    readonly property color sky: "#04a5e5";
    readonly property color sapphire: "#209fb5";
    readonly property color blue: "#1e66f5";
    readonly property color lavender: "#7287fd";
    readonly property color text: "#4c4f69";
    readonly property color subtext1: "#5c5f77";
    readonly property color subtext0: "#6c6f85";
    readonly property color overlay2: "#7c7f93";
    readonly property color overlay1: "#8c8fa1";
    readonly property color overlay0: "#9ca0b0";
    readonly property color surface2: "#acb0be";
    readonly property color surface1: "#bcc0cc";
    readonly property color surface0: "#ccd0da";

    readonly property color base: "#eff1f5";
    readonly property color mantle: "#e6e9ef";
    readonly property color crust: "#dce0e8";
  }

  readonly property var macchiato: QtObject {

    readonly property color rosewater: "#f4dbd6";
    readonly property color flamingo: "#f0c6c6";
    readonly property color pink: "#f5bde6";
    readonly property color mauve: "#c6a0f6";
    readonly property color red: "#ed8796";
    readonly property color maroon: "#ee99a0";
    readonly property color peach: "#f5a97f";
    readonly property color yellow: "#eed49f";
    readonly property color green: "#a6da95";
    readonly property color teal: "#8bd5ca";
    readonly property color sky: "#91d7e3";
    readonly property color sapphire: "#7dc4e4";
    readonly property color blue: "#8aadf4";
    readonly property color lavender: "#b7bdf8";
    readonly property color text: "#cad3f5";
    readonly property color subtext1: "#b8c0e0";
    readonly property color subtext0: "#a5adcb";
    readonly property color overlay2: "#939ab7";
    readonly property color overlay1: "#8087a2";
    readonly property color overlay0: "#6e738d";
    readonly property color surface2: "#5b6078";
    readonly property color surface1: "#494d64";
    readonly property color surface0: "#363a4f";
    readonly property color base: "#24273a";
    readonly property color mantle: "#1e2030";
    readonly property color crust: "#181926";
  }

  property var current: macchiato;

}