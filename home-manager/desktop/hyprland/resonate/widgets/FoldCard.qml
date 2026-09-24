import QtQuick
import QtQuick.Layouts

import qs

// The card a system-panel foldout opens into: a small header (title + one
// text action) over a list that scrolls once it passes `maxHeight`.
Rectangle {
  id: card;

  property string title: "";
  property string action: "";
  property bool actionEnabled: true;
  property real maxHeight: 10000;
  default property alias content: list.data;
  signal actionTapped();

  readonly property real naturalHeight: 8 + 24 + 4 + list.implicitHeight + 8;
  implicitHeight: Math.min(naturalHeight, maxHeight);
  radius: 16;
  color: CurrentTheme.glass;
  border.width: 1;
  border.color: CurrentTheme.border;

  RowLayout {
    id: header;
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 14; rightMargin: 14; }
    height: 24;
    Text {
      Layout.fillWidth: true;
      text: card.title;
      color: CurrentTheme.subtext;
      font.pixelSize: 11; font.weight: Font.Bold;
    }
    Text {
      visible: card.action !== "";
      text: card.action;
      color: CurrentTheme.subtext;
      opacity: card.actionEnabled ? 1 : 0.6;
      font.pixelSize: 11; font.weight: Font.Bold;
      HoverHandler { enabled: card.actionEnabled; cursorShape: Qt.PointingHandCursor; }
      TapHandler { enabled: card.actionEnabled; onTapped: card.actionTapped(); }
    }
  }

  Flickable {
    id: flick;
    anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; topMargin: 4; margins: 8; }
    contentWidth: width;
    contentHeight: list.implicitHeight;
    clip: true;
    interactive: contentHeight > height;
    boundsBehavior: Flickable.StopAtBounds;

    // Below the rows, so their hover still reaches them.
    MouseArea {
      width: flick.width;
      height: Math.max(flick.height, flick.contentHeight);
      acceptedButtons: Qt.NoButton;
      onWheel: (wheel) => {
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - wheel.angleDelta.y));
      }
    }

    ColumnLayout {
      id: list;
      width: flick.width;
      spacing: 2;
    }
  }
}
