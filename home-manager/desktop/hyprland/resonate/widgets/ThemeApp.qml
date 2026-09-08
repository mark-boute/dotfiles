import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Full-takeover theme picker: Catppuccin flavour swatches + accent hues.
// Opened from the drawer's Theme tile. Sizes to its content; the panel gives
// it the width.
ColumnLayout {
  id: root;
  spacing: Theme.defaultSpacing;

  // Width this app asks the panel for (see ControlPanel.appWidth).
  readonly property int appWidth: 460;

  readonly property var flavors: ["latte", "frappe", "macchiato", "mocha"];
  function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

  // --- follow-the-sun toggle ---
  RowLayout {
    Layout.topMargin: Theme.defaultSpacing;
    Layout.alignment: Qt.AlignHCenter;
    spacing: Theme.defaultSpacing;

    Text {
      text: String.fromCodePoint(0xf0599); // md-weather-sunset
      font.family: Theme.iconFontFamily;
      font.pixelSize: Theme.iconSize;
      color: Services.ThemeService.autoMode ? CurrentTheme.accent : CurrentTheme.subtext;
    }
    Text {
      text: "Follow the sun";
      color: CurrentTheme.text;
      font.pixelSize: 12; font.weight: Font.DemiBold;
    }
    PillButton {
      label: Services.ThemeService.autoMode ? "On" : "Off";
      accent: Services.ThemeService.autoMode;
      onClicked: Services.ThemeService.autoMode = !Services.ThemeService.autoMode;
    }
  }

  Text {
    Layout.topMargin: Theme.defaultSpacing;
    Layout.alignment: Qt.AlignHCenter;
    text: "Flavour";
    color: CurrentTheme.subtext;
    font.pixelSize: 12; font.weight: Font.DemiBold;
  }

  RowLayout {
    Layout.alignment: Qt.AlignHCenter;
    spacing: Theme.defaultSpacing;

    Repeater {
      model: root.flavors;

      Rectangle {
        id: swatch;
        required property string modelData;
        readonly property var flavorPalette: Theme.paletteFor(modelData);
        readonly property bool active: Theme.flavor === modelData;

        width: 64; height: 64; radius: 16;
        color: flavorPalette.base;
        border.width: active ? 2 : 1;
        border.color: active ? flavorPalette.mauve : CurrentTheme.border;

        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on border.width { NumberAnimation { duration: 120 } }

        Column {
          anchors.centerIn: parent;
          spacing: 4;
          Row {
            anchors.horizontalCenter: parent.horizontalCenter;
            spacing: 3;
            Repeater {
              model: [swatch.flavorPalette.rosewater, swatch.flavorPalette.mauve, swatch.flavorPalette.blue];
              Rectangle {
                required property color modelData;
                width: 9; height: 9; radius: 4.5;
                color: modelData;
              }
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter;
            text: root.cap(swatch.modelData);
            color: swatch.flavorPalette.text;
            font.pixelSize: 9;
            font.weight: swatch.active ? Font.DemiBold : Font.Normal;
          }
        }

        TapHandler { onTapped: Services.ThemeService.setFlavor(swatch.modelData); }
      }
    }
  }

  Text {
    Layout.topMargin: Theme.defaultSpacing;
    Layout.alignment: Qt.AlignHCenter;
    text: "Accent";
    color: CurrentTheme.subtext;
    font.pixelSize: 12; font.weight: Font.DemiBold;
  }

  Grid {
    Layout.alignment: Qt.AlignHCenter;
    Layout.bottomMargin: Theme.defaultSpacing;
    columns: 7;
    spacing: Theme.defaultSpacing;

    Repeater {
      model: Theme.accentChoices;

      Rectangle {
        id: accentSwatch;
        required property string modelData;
        readonly property bool active: Theme.accentName === modelData;

        width: 32; height: 32; radius: 16;
        color: Theme.palette[modelData];
        border.width: active ? 3 : 0;
        border.color: CurrentTheme.text;

        Behavior on border.width { NumberAnimation { duration: 120 } }

        TapHandler { onTapped: Theme.accentName = accentSwatch.modelData; }
      }
    }
  }
}
