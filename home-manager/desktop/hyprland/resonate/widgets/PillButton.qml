import QtQuick

import qs

// Small pill button used inside the Wi-Fi / Bluetooth inline action rows.
Rectangle {
  id: btn;

  property string label: "";
  property bool accent: false;
  property bool danger: false;
  signal clicked();

  implicitWidth: labelText.implicitWidth + 20;
  implicitHeight: 26;
  radius: 13;
  opacity: enabled ? 1 : 0.4;

  readonly property color base: danger ? CurrentTheme.danger
                                       : (accent ? CurrentTheme.accent : CurrentTheme.border);
  color: hover.hovered && enabled
    ? (accent ? CurrentTheme.accent : Qt.rgba(base.r, base.g, base.b, 0.18))
    : (accent ? CurrentTheme.accent : "transparent");
  border.width: accent ? 0 : 1;
  border.color: base;

  Behavior on color { ColorAnimation { duration: 100 } }

  Text {
    id: labelText;
    anchors.centerIn: parent;
    text: btn.label;
    font.pixelSize: 11;
    font.weight: Font.DemiBold;
    color: btn.accent ? CurrentTheme.background
                      : (btn.danger ? CurrentTheme.danger : CurrentTheme.text);
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; }
  TapHandler { enabled: btn.enabled; onTapped: btn.clicked(); }
}
