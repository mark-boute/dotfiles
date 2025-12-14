import QtQuick
import QtQuick.Layouts
import Quickshell

import qs

Rectangle {

  id: menuDropdownPill;

  height: Theme.barHeight;
  radius: Theme.barHeight / 2;

  color: Theme.current.overlay0;
  border.width: 1;
  border.color: Theme.current.crust;

  property alias menuContent: contentContainer.data;

  // The pill that shows in the bar
  Rectangle {
    id: menuPill;
    height: Theme.barHeight;
    radius: Theme.barHeight / 2;

    anchors.top: parent.top;
    anchors.horizontalCenter: parent.horizontalCenter

    color: Theme.current.base;
    border.width: 1;
    border.color: Theme.current.crust;
    implicitWidth: contentContainer.implicitWidth > 0 
      ? contentContainer.implicitWidth + Theme.defaultMargin * 2
      : 0;
    
    implicitHeight: Theme.barHeight;

    RowLayout {
        id: contentContainer
        anchors.fill: parent
        anchors.leftMargin: Theme.defaultMargin
        // spacing: Theme.defaultSpacing
        Layout.alignment: Qt.AlignHCenter
    }
  }
}