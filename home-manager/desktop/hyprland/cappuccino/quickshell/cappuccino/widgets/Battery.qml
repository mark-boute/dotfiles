import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick

import qs
import qs.shapes as S

S.MenuPill {
  visible: UPower.displayDevice.isLaptopBattery;

  id: batteryWidget;
  implicitWidth: batteryText.implicitWidth + Theme.defaultMargin * 2;
  
  Text {
    id: batteryText;
    text: Math.floor(UPower.displayDevice.percentage * 100) + "%";
    font.pixelSize: 14;
    font.weight: Font.DemiBold;
    color: {
      if (UPower.displayDevice.timeToEmpty === 0) {
        return Theme.current.blue;
      }
      if (UPower.displayDevice.percentage <= 0.2) {
        return Theme.current.red;
      }
      if (UPower.displayDevice.percentage <= 0.4) {
        return Theme.current.peach;
      }
      return Theme.current.green;
    }
    verticalAlignment: Text.AlignVCenter
    anchors.centerIn: parent;
  }
}
