import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Rows for the system panel's Wi-Fi foldout (FoldCard owns the header and
// Rescan). Tapping a network opens an inline row under it: a password field
// for secured networks with no saved profile, then Connect / Disconnect and
// Forget.
ColumnLayout {
  id: root;

  readonly property var svc: Services.NetworkService;

  // Only one row open at a time; keyed by ssid so it survives the network
  // list being rebuilt on refresh.
  property string openSsid: "";
  property string password: "";
  onOpenSsidChanged: password = "";

  spacing: 2;

  function _bars(signal) { return Math.max(1, Math.min(4, Math.ceil(signal / 25))); }

  Text {
    visible: !root.svc.enabled || (root.svc.networks.length === 0 && !root.svc.scanning);
    Layout.fillWidth: true;
    Layout.margins: 6;
    text: root.svc.enabled ? "No networks found" : "Wi-Fi is off";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }

  Repeater {
    model: root.svc.enabled ? root.svc.networks : [];

    delegate: ColumnLayout {
      id: row;
      required property var modelData;
      readonly property bool isOpen: root.openSsid === modelData.ssid;
      readonly property bool busy: root.svc.busySsid === modelData.ssid;
      readonly property bool needsPassword: modelData.secure && !modelData.saved && !modelData.active;

      Layout.fillWidth: true;
      spacing: 0;

      FoldRow {
        Layout.fillWidth: true;
        name: row.modelData.ssid;
        bold: row.modelData.active;
        highlighted: row.isOpen;
        bars: root._bars(row.modelData.signal);
        busy: row.busy;
        status: row.modelData.active && !row.busy ? "Connected" : "";
        trailGlyph: row.modelData.secure ? String.fromCodePoint(0xf033e) : ""; // md-lock
        onTapped: root.openSsid = row.isOpen ? "" : row.modelData.ssid;
      }

      ColumnLayout {
        visible: row.isOpen;
        Layout.fillWidth: true;
        Layout.leftMargin: 10;
        Layout.rightMargin: 10;
        Layout.topMargin: 4;
        Layout.bottomMargin: 4;
        spacing: 6;

        Rectangle {
          visible: row.needsPassword;
          Layout.fillWidth: true;
          implicitHeight: 30;
          radius: 10;
          color: CurrentTheme.well;
          border.width: 1;
          border.color: pwInput.activeFocus ? CurrentTheme.accent : CurrentTheme.border;

          TextInput {
            id: pwInput;
            anchors.fill: parent;
            anchors.leftMargin: 10;
            anchors.rightMargin: 10;
            verticalAlignment: TextInput.AlignVCenter;
            color: CurrentTheme.text;
            font.pixelSize: 12;
            echoMode: TextInput.Password;
            clip: true;
            text: root.password;
            onTextChanged: root.password = text;
            onAccepted: root.svc.connect(row.modelData.ssid, root.password);

            Text {
              anchors.fill: parent;
              verticalAlignment: Text.AlignVCenter;
              visible: pwInput.text === "";
              text: "Password";
              color: CurrentTheme.subtext;
              font: pwInput.font;
            }
          }
        }

        Text {
          visible: root.svc.errorSsid === row.modelData.ssid && root.svc.errorText !== "";
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
            visible: !row.modelData.active;
            label: "Connect";
            enabled: !row.busy && (!row.needsPassword || root.password.length > 0);
            accent: true;
            onClicked: root.svc.connect(row.modelData.ssid, root.password);
          }
          PillButton {
            visible: row.modelData.active;
            label: "Disconnect";
            onClicked: { root.svc.disconnect(); root.openSsid = ""; }
          }
          Item { Layout.fillWidth: true; }
          PillButton {
            visible: row.modelData.saved;
            label: "Forget";
            plain: true;
            onClicked: { root.svc.forget(row.modelData.ssid); root.openSsid = ""; }
          }
        }
      }
    }
  }
}
