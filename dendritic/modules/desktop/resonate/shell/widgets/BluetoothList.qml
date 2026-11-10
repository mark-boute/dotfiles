import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Rows for the system panel's Bluetooth foldout (FoldCard owns the header
// and Scan). Tapping a device opens Connect / Disconnect and Forget under it.
ColumnLayout {
  id: root;

  readonly property var svc: Services.BluetoothService;

  // One row open at a time; keyed by mac so it survives rebuilds.
  property string openMac: "";

  spacing: 2;

  function glyphFor(name) {
    var n = (name || "").toLowerCase();
    if (/buds|pods|head|ear|wh-|wf-|jabra|bose/.test(n)) return 0xf02cb; // md-headphones
    if (/mouse|mx /.test(n)) return 0xf037d;                              // md-mouse
    if (/keyboard|keys/.test(n)) return 0xf030c;                          // md-keyboard
    if (/phone|pixel|iphone|galaxy/.test(n)) return 0xf011c;              // md-cellphone
    if (/speaker|soundbar|sonos/.test(n)) return 0xf04c3;                 // md-speaker
    return 0xf00af;                                                       // md-bluetooth
  }

  Text {
    visible: !root.svc.enabled || root.svc.devices.length === 0;
    Layout.fillWidth: true;
    Layout.margins: 6;
    text: !root.svc.enabled ? "Bluetooth is off"
      : root.svc.scanning ? "Looking for devices…" : "Tap Scan to look for devices";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
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

      FoldRow {
        Layout.fillWidth: true;
        name: row.modelData.name;
        bold: row.modelData.connected;
        highlighted: row.isOpen;
        glyph: String.fromCodePoint(root.glyphFor(row.modelData.name));
        busy: row.busy;
        status: row.busy ? ""
          : row.modelData.connected
            ? (row.modelData.battery >= 0 ? "Connected · " + row.modelData.battery + "%" : "Connected")
            : (row.modelData.paired ? "Paired" : "");
        onTapped: root.openMac = row.isOpen ? "" : row.modelData.mac;
      }

      ColumnLayout {
        visible: row.isOpen;
        Layout.fillWidth: true;
        Layout.leftMargin: 10;
        Layout.rightMargin: 10;
        Layout.topMargin: 4;
        Layout.bottomMargin: 4;
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
          spacing: 8;

          PillButton {
            visible: !row.modelData.connected;
            label: row.modelData.paired ? "Connect" : "Pair & connect";
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
            plain: true;
            enabled: !row.busy;
            onClicked: { root.svc.forget(row.modelData.mac); root.openMac = ""; }
          }
        }
      }
    }
  }
}
