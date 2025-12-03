import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick

import qs.shapes as S

S.MenuPill {
  visible: UPower.displayDevice.isLaptopBattery;

  id: batteryWidget;
  width: batteryText.width + 20;
  
  Text {
    id: batteryText;
    text: UPower.displayDevice.percentage.toFixed(2) * 100 + "%";
    font.pixelSize: 14;
    font.weight: Font.DemiBold;
    color: {
      if (UPower.displayDevice.timeToEmpty === 0) {
        return "#8aadf4";
      }
      if (UPower.displayDevice.percentage <= 0.2) {
        return "#ed8796";
      }
      if (UPower.displayDevice.percentage <= 0.4) {
        return "#f5a97f";
      }
      return "#a6da95";
    }
    verticalAlignment: Text.AlignVCenter
    anchors.centerIn: parent;
  }
}
