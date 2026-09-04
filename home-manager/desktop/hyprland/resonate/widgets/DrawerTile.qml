import QtQuick

import qs

// A rounded, tappable tile for the apps drawer. Just the interactive container
// + hover feedback; each tile composes its own status preview inside. Clicking
// it emits activated() — the panel swaps to that app's full-takeover view.
Rectangle {
  id: tile;

  default property alias content: inner.data;
  signal activated();

  radius: 16;
  color: hover.hovered ? CurrentTheme.surfaceHover : CurrentTheme.backgroundGlass;
  border.width: 1;
  border.color: hover.hovered ? CurrentTheme.accent : CurrentTheme.border;

  Behavior on color { ColorAnimation { duration: 100 } }
  Behavior on border.color { ColorAnimation { duration: 100 } }

  Item {
    id: inner;
    anchors.fill: parent;
    anchors.margins: 12;
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; }
  TapHandler { onTapped: tile.activated(); }
}
