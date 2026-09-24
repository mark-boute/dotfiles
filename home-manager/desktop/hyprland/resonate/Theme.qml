pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: theme;

  // Which Catppuccin flavor is active. The accent is fixed per flavor: same
  // lightness and softness everywhere, hue taken from that flavor's wallpaper.
  property string flavor: "macchiato";

  readonly property var flavorAccents: ({
    "latte": "#097689",
    "frappe": "#99d1db",
    "macchiato": "#b2baee",
    "mocha": "#8bc8de",
  });
  readonly property color accent: flavorAccents[flavor] || flavorAccents.macchiato;

  // The pointer stays rosewater whatever the flavor.
  readonly property string cursorAccent: "rosewater";

  // latte is the only light flavor; the other three are all dark.
  readonly property bool isLight: flavor === "latte";

  // Push the light/dark choice to the system so apps that honour
  // `prefers-color-scheme` (browsers via xdg-desktop-portal, libadwaita, …)
  // flip with the bar's flavour. xdg-desktop-portal-gtk maps this gsettings
  // key straight onto org.freedesktop.appearance color-scheme.
  Process { id: colorSchemeProc; }
  function _syncColorScheme() {
    colorSchemeProc.command = ["gsettings", "set", "org.gnome.desktop.interface",
      "color-scheme", theme.isLight ? "prefer-light" : "prefer-dark"];
    colorSchemeProc.running = true;
  }
  onIsLightChanged: _syncColorScheme();
  Component.onCompleted: _syncColorScheme();

  function paletteFor(name) {
    if (name === "latte") return latte;
    if (name === "frappe") return frappe;
    if (name === "mocha") return mocha;
    return macchiato;
  }

  readonly property var palette: paletteFor(flavor);

  readonly property string assetDir: "/home/mark/dotfiles/home-manager/desktop/hyprland/resonate/assets/background/sailboat-daytimes";

  function backgroundFor(name) {
    if (name === "latte" || name === "frappe") return assetDir + "/day.jpg";
    if (name === "mocha") return assetDir + "/night.jpg";
    // macchiato gets sunset — there's no dedicated 4th image.
    return assetDir + "/sunset.jpg";
  }

  readonly property string backgroundImage: backgroundFor(flavor);

  // Already installed for the terminal (powerlevel10k needs it), and its
  // Nerd Font glyph set covers everything resonate needs — using it means
  // status icons are just colored Text, no icon-theme file lookup and no
  // shader-based recoloring required.
  readonly property string iconFontFamily: "JetBrainsMono Nerd Font";

  // Shared target size for any status/control icon (Nerd Font glyph or a
  // raster tray IconImage) so mixed icon rows read as one consistent set
  // rather than a jumble of whatever size each glyph happens to render at
  // by default.
  readonly property int iconSize: 18;

  // Bar sizing. Widgets that sit in the bar read this for their collapsed
  // (unhovered) footprint — that footprint is what actually reserves space
  // via the panel's exclusiveZone, so it's the true "bar height".
  property int barHeight: 32;
  property int barVerticalMargin: 4;
  property int barHorizontalMargin: 4;

  // The bar's three islands (workspaces/clock/power) hang as rounded-
  // bottom "notches" below one full-width connecting strip of the same
  // frosted-glass fill, flush against the top of the screen. This is that
  // strip's height — about 2/5 of an island's own idle height.
  readonly property int barConnectorHeight: Math.round(barHeight / 4);

  // Radius of the concave nodge smoothing each seam between a slot and the
  // connecting strip — one segment of Bar.qml's single BarSurface path
  // (barOutline()), not a separate item.
  readonly property int nodgeRadius: Math.min(16, barHeight / 2);

  readonly property int defaultMargin: 14;
  readonly property int defaultSpacing: 8;

  // Tallest an open panel may get, margins included; past it the body
  // scrolls. The bar window is sized from this plus panelShadowRoom, so a
  // full panel still shows its bottom margin, rounded corners and shadow
  // instead of being cut off at the window edge.
  readonly property int maxPanelHeight: 668;
  readonly property int maxPanelContentHeight: maxPanelHeight - defaultMargin * 2;
  readonly property int panelShadowRoom: 16;

  // Drop shadow shared by every bar pill and panel, via layer.effect +
  // MultiEffect on each one's own root Rectangle — gives the frosted-glass
  // surfaces some lift off the wallpaper behind them.
  readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.45);
  readonly property real shadowBlur: 0.5;
  readonly property int shadowVerticalOffset: 3;

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

  readonly property var frappe: QtObject {
    readonly property color rosewater: "#f2d5cf";
    readonly property color flamingo: "#eebebe";
    readonly property color pink: "#f4b8e4";
    readonly property color mauve: "#ca9ee6";
    readonly property color red: "#e78284";
    readonly property color maroon: "#ea999c";
    readonly property color peach: "#ef9f76";
    readonly property color yellow: "#e5c890";
    readonly property color green: "#a6d189";
    readonly property color teal: "#81c8be";
    readonly property color sky: "#99d1db";
    readonly property color sapphire: "#85c1dc";
    readonly property color blue: "#8caaee";
    readonly property color lavender: "#babbf1";
    readonly property color text: "#c6d0f5";
    readonly property color subtext1: "#b5bfe2";
    readonly property color subtext0: "#a5adce";
    readonly property color overlay2: "#949cbb";
    readonly property color overlay1: "#838ba7";
    readonly property color overlay0: "#737994";
    readonly property color surface2: "#626880";
    readonly property color surface1: "#51576d";
    readonly property color surface0: "#414559";
    readonly property color base: "#303446";
    readonly property color mantle: "#292c3c";
    readonly property color crust: "#232634";
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

  readonly property var mocha: QtObject {
    readonly property color rosewater: "#f5e0dc";
    readonly property color flamingo: "#f2cdcd";
    readonly property color pink: "#f5c2e7";
    readonly property color mauve: "#cba6f7";
    readonly property color red: "#f38ba8";
    readonly property color maroon: "#eba0ac";
    readonly property color peach: "#fab387";
    readonly property color yellow: "#f9e2af";
    readonly property color green: "#a6e3a1";
    readonly property color teal: "#94e2d5";
    readonly property color sky: "#89dceb";
    readonly property color sapphire: "#74c7ec";
    readonly property color blue: "#89b4fa";
    readonly property color lavender: "#b4befe";
    readonly property color text: "#cdd6f4";
    readonly property color subtext1: "#bac2de";
    readonly property color subtext0: "#a6adc8";
    readonly property color overlay2: "#9399b2";
    readonly property color overlay1: "#7f849c";
    readonly property color overlay0: "#6c7086";
    readonly property color surface2: "#585b70";
    readonly property color surface1: "#45475a";
    readonly property color surface0: "#313244";
    readonly property color base: "#1e1e2e";
    readonly property color mantle: "#181825";
    readonly property color crust: "#11111b";
  }
}
