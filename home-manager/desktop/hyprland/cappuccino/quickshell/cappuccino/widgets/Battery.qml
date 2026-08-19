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
  clip: true;
  implicitWidth: content.implicitWidth + Theme.defaultMargin * 2;

  // Expanded view shows on hover, or stays open when toggled on by a click.
  property bool pinned: false;
  readonly property bool expanded: hoverArea.containsMouse || pinned;

  // Track whether each threshold warning has already fired this discharge cycle.
  property bool _warned20: false;
  property bool _warned10: false;

  // --- live data for the expanded view (polled only while expanded) ---
  FileView {
    id: gpuStateFile;
    path: "/sys/bus/pci/devices/0000:01:00.0/power_state";
    property string value: "";
    onLoaded: value = text().trim();
  }

  // nvidia-smi wakes the card and resets its runtime-PM idle timer, so calling
  // it on a poll would pin the GPU at D0 forever. Only measure when a *real*
  // client (a process other than this probe) holds /dev/nvidia0; otherwise the
  // card is idle/asleep and draws ~0 W, so just report 0 without touching it.
  property real gpuWatts: 0;
  Process {
    id: gpuPowerProc;
    command: ["sh", "-c",
      "s=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state); " +
      "[ \"$s\" = D3cold ] && { echo 0; exit; }; " +
      "ls -l /proc/[0-9]*/fd 2>/dev/null | grep -q /dev/nvidia0 " +
      "&& nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits || echo 0"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        batteryWidget.gpuWatts = parseFloat(t) || 0;
      }
    }
  }

  Timer {
    interval: 1500;
    repeat: true;
    triggeredOnStart: true;
    running: batteryWidget.expanded;
    onTriggered: { gpuStateFile.reload(); gpuPowerProc.running = true; }
  }

  readonly property bool gpuAsleep: gpuStateFile.value === "D3cold";
  readonly property real powerDraw: Math.abs(UPower.displayDevice.changeRate);

  Row {
    id: content;
    anchors.left: parent.left;
    anchors.leftMargin: Theme.defaultMargin;
    anchors.verticalCenter: parent.verticalCenter;
    spacing: Theme.defaultSpacing;

    Text {
      id: batteryText;
      anchors.verticalCenter: parent.verticalCenter;
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
    }

    // Reveals to the left of the percentage; width animates 0 -> content.
    Item {
      id: detailsWrap;
      anchors.verticalCenter: parent.verticalCenter;
      clip: true;
      height: detailsRow.implicitHeight;
      width: batteryWidget.expanded ? detailsRow.implicitWidth : 0;
      opacity: batteryWidget.expanded ? 1 : 0;

      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 120 } }

      Row {
        id: detailsRow;
        anchors.left: parent.left;
        anchors.verticalCenter: parent.verticalCenter;
        spacing: Theme.defaultSpacing;

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter;
          width: 1;
          height: Theme.barHeight * 0.5;
          color: Theme.current.overlay0;
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter;
          text: batteryWidget.powerDraw.toFixed(1) + " W";
          font.pixelSize: 13;
          color: Theme.current.subtext1;
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter;
          text: "GPU " + (batteryWidget.gpuAsleep ? "0.0" : (batteryWidget.gpuWatts || 0).toFixed(1)) + " W";
          font.pixelSize: 13;
          color: batteryWidget.gpuAsleep ? Theme.current.subtext0 : Theme.current.peach;
        }
      }
    }
  }

  MouseArea {
    id: hoverArea;
    anchors.fill: parent;
    hoverEnabled: true;
    cursorShape: Qt.PointingHandCursor;
    onClicked: batteryWidget.pinned = !batteryWidget.pinned;
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
