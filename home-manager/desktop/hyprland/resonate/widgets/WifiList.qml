import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// The Wi-Fi dropdown for the power panel: a rescan control and the list of
// visible networks. Tapping a network expands an inline connect row — a
// password field for secured networks with no saved profile, or straight
// Connect / Disconnect / Forget otherwise.
ColumnLayout {
  id: root;

  readonly property var svc: Services.NetworkService;

  // Only one row's connect UI open at a time; keyed by ssid so it survives the
  // network list being rebuilt on refresh.
  property string openSsid: "";
  property string password: "";
  onOpenSsidChanged: password = "";

  spacing: 4;

  function _bars(signal) { return Math.max(1, Math.min(4, Math.ceil(signal / 25))); }

  Text {
    visible: !root.svc.enabled;
    Layout.fillWidth: true;
    text: "Wi-Fi is off";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }

  RowLayout {
    visible: root.svc.enabled;
    Layout.fillWidth: true;
    Layout.bottomMargin: 2;

    Text {
      text: "Networks";
      color: CurrentTheme.subtext;
      font.pixelSize: 11; font.weight: Font.DemiBold;
    }
    Item { Layout.fillWidth: true; }
    Text {
      text: root.svc.scanning ? "Scanning…" : "Rescan";
      color: root.svc.scanning ? CurrentTheme.subtext : CurrentTheme.accent;
      font.pixelSize: 11; font.weight: Font.DemiBold;
      TapHandler { enabled: !root.svc.scanning; onTapped: root.svc.scan(); }
    }
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

          // signal strength bars
          Item {
            implicitWidth: 16; implicitHeight: 12;
            Layout.alignment: Qt.AlignVCenter;
            Repeater {
              model: 4;
              Rectangle {
                required property int index;
                width: 3;
                height: 3 + index * 3;
                x: index * 4.3;
                anchors.bottom: parent.bottom;
                radius: 1;
                color: (index < root._bars(row.modelData.signal))
                  ? (row.modelData.active ? CurrentTheme.success : CurrentTheme.text)
                  : Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.2);
              }
            }
          }

          Text {
            text: row.modelData.ssid;
            color: CurrentTheme.text;
            font.pixelSize: 12;
            font.weight: row.modelData.active ? Font.DemiBold : Font.Normal;
            elide: Text.ElideRight;
            Layout.fillWidth: true;
          }

          Text {
            visible: row.modelData.secure;
            text: String.fromCodePoint(0xf023); // lock
            font.family: Theme.iconFontFamily;
            font.pixelSize: 10;
            color: CurrentTheme.subtext;
          }

          Text {
            visible: row.modelData.active || row.busy;
            text: row.busy ? "…" : "Connected";
            color: CurrentTheme.success;
            font.pixelSize: 10; font.weight: Font.DemiBold;
          }
        }

        HoverHandler { id: rowHover; }
        TapHandler {
          onTapped: {
            if (row.modelData.active || row.modelData.saved || !row.modelData.secure) {
              // No password needed — connect (or just toggle the actions row).
              root.openSsid = row.isOpen ? "" : row.modelData.ssid;
            } else {
              root.openSsid = row.isOpen ? "" : row.modelData.ssid;
            }
          }
        }
      }

      // --- inline connect / disconnect row ---
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

          // password field (secured, unsaved)
          Rectangle {
            visible: row.needsPassword;
            Layout.fillWidth: true;
            implicitHeight: 30;
            radius: 7;
            color: CurrentTheme.surface;
            border.width: 1;
            border.color: pwInput.activeFocus ? CurrentTheme.accent : CurrentTheme.border;

            TextInput {
              id: pwInput;
              anchors.fill: parent;
              anchors.leftMargin: 9;
              anchors.rightMargin: 9;
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
            spacing: 6;

            PillButton {
              visible: !row.modelData.active;
              label: row.busy ? "Connecting…" : "Connect";
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
              danger: true;
              onClicked: { root.svc.forget(row.modelData.ssid); root.openSsid = ""; }
            }
          }
        }
      }
    }
  }

  Text {
    visible: root.svc.enabled && root.svc.networks.length === 0 && !root.svc.scanning;
    Layout.fillWidth: true;
    Layout.topMargin: 4;
    text: "No networks found";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }
}
