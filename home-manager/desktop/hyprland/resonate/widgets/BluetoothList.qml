import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// The Bluetooth dropdown for the power panel: a scan control and the list of
// known/discovered devices. Tapping a device expands inline Connect /
// Disconnect / Forget actions.
ColumnLayout {
  id: root;

  readonly property var svc: Services.BluetoothService;

  // One row's action UI open at a time; keyed by mac so it survives rebuilds.
  property string openMac: "";

  spacing: 4;

  Text {
    visible: !root.svc.enabled;
    Layout.fillWidth: true;
    text: "Bluetooth is off";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }

  RowLayout {
    visible: root.svc.enabled;
    Layout.fillWidth: true;
    Layout.bottomMargin: 2;

    Text {
      text: "Devices";
      color: CurrentTheme.subtext;
      font.pixelSize: 11; font.weight: Font.DemiBold;
    }
    Item { Layout.fillWidth: true; }
    Text {
      text: root.svc.scanning ? "Scanning…" : "Scan";
      color: root.svc.scanning ? CurrentTheme.subtext : CurrentTheme.accent;
      font.pixelSize: 11; font.weight: Font.DemiBold;
      TapHandler { enabled: !root.svc.scanning; onTapped: root.svc.scan(); }
    }
  }

  Repeater {
    model: root.svc.enabled ? root.svc.devices : [];

    delegate: ColumnLayout {
      id: row;
      required property var modelData;
      readonly property bool isOpen: root.openMac === modelData.mac;
      readonly property bool busy: root.svc.busyMac === modelData.mac;

      Layout.fillWidth: true;
      spacing: 0;

      Rectangle {
        Layout.fillWidth: true;
        implicitHeight: 34;
        radius: 8;
        color: rowHover.hovered || row.isOpen ? CurrentTheme.surfaceHover : "transparent";

        RowLayout {
          anchors.fill: parent;
          anchors.leftMargin: 8;
          anchors.rightMargin: 10;
          spacing: 8;

          Text {
            text: String.fromCodePoint(row.modelData.connected ? 0xf00b1 : 0xf00af);
            font.family: Theme.iconFontFamily;
            font.pixelSize: 13;
            color: row.modelData.connected ? CurrentTheme.success : CurrentTheme.subtext;
          }
          Text {
            text: row.modelData.name;
            color: CurrentTheme.text;
            font.pixelSize: 12;
            font.weight: row.modelData.connected ? Font.DemiBold : Font.Normal;
            elide: Text.ElideRight;
            Layout.fillWidth: true;
          }
          Text {
            visible: row.busy || row.modelData.connected || row.modelData.paired;
            text: row.busy ? "…" : (row.modelData.connected ? "Connected" : "Paired");
            color: row.modelData.connected ? CurrentTheme.success : CurrentTheme.subtext;
            font.pixelSize: 10; font.weight: Font.DemiBold;
          }
        }

        HoverHandler { id: rowHover; }
        TapHandler { onTapped: root.openMac = row.isOpen ? "" : row.modelData.mac; }
      }

      Rectangle {
        Layout.fillWidth: true;
        Layout.topMargin: row.isOpen ? 4 : 0;
        implicitHeight: row.isOpen ? inner.implicitHeight + 12 : 0;
        clip: true;
        radius: 8;
        color: CurrentTheme.backgroundGlass;
        visible: row.isOpen;

        ColumnLayout {
          id: inner;
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6; }
          spacing: 6;

          Text {
            visible: root.svc.errorMac === row.modelData.mac && root.svc.errorText !== "";
            Layout.fillWidth: true;
            text: root.svc.errorText;
            color: CurrentTheme.danger;
            font.pixelSize: 10;
            wrapMode: Text.WordWrap;
          }

          RowLayout {
            Layout.fillWidth: true;
            spacing: 6;

            PillButton {
              visible: !row.modelData.connected;
              label: row.busy ? "Connecting…" : (row.modelData.paired ? "Connect" : "Pair & connect");
              enabled: !row.busy;
              accent: true;
              onClicked: root.svc.connect(row.modelData.mac);
            }
            PillButton {
              visible: row.modelData.connected;
              label: "Disconnect";
              enabled: !row.busy;
              onClicked: root.svc.disconnect(row.modelData.mac);
            }
            Item { Layout.fillWidth: true; }
            PillButton {
              visible: row.modelData.paired;
              label: "Forget";
              danger: true;
              enabled: !row.busy;
              onClicked: { root.svc.forget(row.modelData.mac); root.openMac = ""; }
            }
          }
        }
      }
    }
  }

  Text {
    visible: root.svc.enabled && root.svc.devices.length === 0;
    Layout.fillWidth: true;
    Layout.topMargin: 4;
    text: root.svc.scanning ? "Looking for devices…" : "Tap Scan to look for devices";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }
}
