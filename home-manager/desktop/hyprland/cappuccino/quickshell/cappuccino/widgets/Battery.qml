import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

import qs
import qs.shapes as S

S.MenuPill {
  visible: UPower.displayDevice.isLaptopBattery;

  id: batteryWidget;
  implicitWidth: batteryText.implicitWidth + Theme.defaultMargin * 2;

  // Track whether each threshold warning has already fired this discharge cycle.
  property bool _warned20: false;
  property bool _warned10: false;

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
    verticalAlignment: Text.AlignVCenter;
    anchors.centerIn: parent;
  }

  Connections {
    target: UPower.displayDevice;
    function onPercentageChanged() {
      var pct = UPower.displayDevice.percentage;
      var discharging = UPower.displayDevice.timeToEmpty > 0;

      if (!discharging) {
        // Charging — reset so warnings fire again on the next discharge cycle.
        batteryWidget._warned20 = false;
        batteryWidget._warned10 = false;
        return;
      }
      if (pct <= 0.10 && !batteryWidget._warned10) {
        batteryWidget._warned10 = true;
        criticalBatteryNotify.running = true;
      } else if (pct <= 0.20 && !batteryWidget._warned20) {
        batteryWidget._warned20 = true;
        lowBatteryNotify.running = true;
      }
    }
  }

  Process {
    id: lowBatteryNotify;
    command: ["notify-send", "-u", "normal", "-a", "Battery",
              "Low Battery", "20% remaining — consider plugging in"];
  }

  Process {
    id: criticalBatteryNotify;
    command: ["notify-send", "-u", "critical", "-a", "Battery",
              "Critical Battery", "10% remaining — plug in now"];
  }
}
