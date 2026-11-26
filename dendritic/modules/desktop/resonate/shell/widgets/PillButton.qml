import QtQuick

import qs

// Small pill button for inline action rows. `accent` fills it; `plain` is
// just a subtext label (secondary actions like Forget); otherwise outlined.
Rectangle {
  id: btn;

  property string label: "";
  property bool accent: false;
  property bool danger: false;
  property bool plain: false;
  signal clicked();

  implicitWidth: labelText.implicitWidth + (plain ? 24 : 28);
  implicitHeight: 28;
  radius: 14;
  opacity: enabled ? 1 : 0.4;

  readonly property color base: danger ? CurrentTheme.danger
                                       : (accent ? CurrentTheme.accent : CurrentTheme.border);
  color: accent ? CurrentTheme.accent
    : (hover.hovered && enabled ? (plain ? CurrentTheme.chip : Qt.rgba(base.r, base.g, base.b, 0.18)) : "transparent");
  border.width: accent || plain ? 0 : 1;
  border.color: base;

  Behavior on color { ColorAnimation { duration: 100 } }

  Text {
    id: labelText;
    anchors.centerIn: parent;
    text: btn.label;
    font.pixelSize: 11;
    font.weight: Font.Bold;
    color: btn.accent ? CurrentTheme.background
      : btn.danger ? CurrentTheme.danger
      : btn.plain ? CurrentTheme.subtext : CurrentTheme.text;
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; }
  TapHandler { enabled: btn.enabled; onTapped: btn.clicked(); }
}
