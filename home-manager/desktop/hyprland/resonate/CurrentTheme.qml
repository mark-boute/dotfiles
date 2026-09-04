pragma Singleton

import Quickshell
import QtQuick

import qs

// The semantic colors components should actually bind to (CurrentTheme.text,
// CurrentTheme.accent, ...) instead of reaching into Theme.palette.<catppuccin
// name> themselves. Every property here is a live binding to Theme.palette,
// so switching Theme.flavor updates every consumer automatically.
Singleton {
  // Solid — for text/icons drawn *on top of* an accent-filled shape, where
  // see-through would break contrast. Cards and tracks use backgroundGlass.
  readonly property color background:   Theme.palette.base;

  // Translucent — paired with the "quickshell:resonate:bar" layer_rule in
  // hypr/appearance.lua, which is what actually blurs whatever shows
  // through. Without that compositor-side blur these would just look like
  // plain see-through color, not frosted glass.
  readonly property color surface:      Qt.rgba(Theme.palette.surface0.r, Theme.palette.surface0.g, Theme.palette.surface0.b, 0.72);
  // Same frostiness as `surface` but keyed on `base` — a step deeper, so the
  // cards / tracks / pills that sit inside a panel read as recessed while
  // still letting the blur bleed through (a solid dark block looked abrupt
  // over a bright wallpaper or website).
  readonly property color backgroundGlass: Qt.rgba(Theme.palette.base.r, Theme.palette.base.g, Theme.palette.base.b, 0.72);
  readonly property color surfaceHover: Qt.rgba(Theme.palette.surface1.r, Theme.palette.surface1.g, Theme.palette.surface1.b, 0.82);
  readonly property color border:       Theme.palette.surface2;
  readonly property color text:         Theme.palette.text;
  readonly property color subtext:      Theme.palette.subtext0;
  readonly property color accent:       Theme.palette[Theme.accentName];
  readonly property color success:      Theme.palette.green;
  readonly property color warning:      Theme.palette.peach;
  readonly property color danger:       Theme.palette.red;

  // A green-washed row background for finished/checked items — mirrors the
  // website's `--caught-bg: color-mix(in srgb, green 18%, base)`. Frosted to
  // match backgroundGlass.
  readonly property color caughtBackground: Qt.rgba(
    Theme.palette.green.r * 0.20 + Theme.palette.base.r * 0.80,
    Theme.palette.green.g * 0.20 + Theme.palette.base.g * 0.80,
    Theme.palette.green.b * 0.20 + Theme.palette.base.b * 0.80,
    0.72);
}
