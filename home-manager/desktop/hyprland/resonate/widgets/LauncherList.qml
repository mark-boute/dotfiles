import QtQuick

import qs

// A launcher result list: a plain ListView that keeps its current row
// scrolled into view (driven by LauncherService's selection index) and
// shows a centred message when empty.
ListView {
  id: list;

  property string emptyText: "";

  clip: true;
  spacing: 2;
  boundsBehavior: Flickable.StopAtBounds;
  flickableDirection: Flickable.VerticalFlick;
  currentIndex: 0;
  highlightMoveDuration: 110;

  onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain);
  onCountChanged: if (currentIndex < count) positionViewAtIndex(currentIndex, ListView.Contain);

  Text {
    anchors.centerIn: parent;
    width: parent.width - 24;
    horizontalAlignment: Text.AlignHCenter;
    wrapMode: Text.WordWrap;
    visible: list.count === 0 && list.emptyText !== "";
    text: list.emptyText;
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }
}
