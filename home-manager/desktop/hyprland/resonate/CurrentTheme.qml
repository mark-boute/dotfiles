pragma Singleton

import Quickshell
import QtQuick

import qs

// The semantic colors components should actually bind to (CurrentTheme.text,
// CurrentTheme.accent, ...) instead of reaching into Theme.palette.<catppuccin
// name> themselves. Every property here is a live binding to Theme.palette,
// so switching Theme.flavor updates every consumer automatically.
Singleton {
  readonly property color background:   Theme.palette.base;
  // Translucent — paired with the "quickshell:resonate:bar" layer_rule in
  // hypr/appearance.lua, which is what actually blurs whatever shows
  // through. Without that compositor-side blur this would just look like
  // plain see-through color, not frosted glass.
  readonly property color surface:      Qt.rgba(Theme.palette.surface0.r, Theme.palette.surface0.g, Theme.palette.surface0.b, 0.72);
  readonly property color surfaceHover: Theme.palette.surface1;
  readonly property color border:       Theme.palette.surface2;
  readonly property color text:         Theme.palette.text;
  readonly property color subtext:      Theme.palette.subtext0;
  readonly property color accent:       Theme.palette[Theme.accentName];
  readonly property color success:      Theme.palette.green;
  readonly property color warning:      Theme.palette.peach;
  readonly property color danger:       Theme.palette.red;
}
