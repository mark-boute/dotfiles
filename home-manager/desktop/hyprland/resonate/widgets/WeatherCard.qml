import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Home-view weather: current conditions + 3-day, and a tap reveals the
// horizontally-scrolling hourly strip.
Rectangle {
  id: root;

  visible: Services.WeatherService.ready;
  implicitHeight: col.implicitHeight + Theme.defaultSpacing * 2;
  radius: 14;
  color: CurrentTheme.backgroundGlass;
  border.width: 1;
  border.color: CurrentTheme.border;

  Behavior on implicitHeight { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  clip: true;

  property bool showHourly: false;

  ColumnLayout {
    id: col;
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.defaultSpacing; }
    spacing: Theme.defaultSpacing;

    RowLayout {
      Layout.fillWidth: true;
      spacing: Theme.defaultSpacing;

      Text {
        text: Services.WeatherService.glyph;
        font.family: Theme.iconFontFamily;
        font.pixelSize: 30;
        color: CurrentTheme.text;
      }
      ColumnLayout {
        spacing: 0;
        Text {
          text: Math.round(Services.WeatherService.temp) + "°";
          color: CurrentTheme.text;
          font.pixelSize: 20; font.weight: Font.DemiBold;
        }
        Text {
          text: Services.WeatherService.desc;
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
        }
      }

      Item { Layout.fillWidth: true; }

      Repeater {
        model: Services.WeatherService.daily;
        delegate: ColumnLayout {
          required property var modelData;
          spacing: 1;
          Text { Layout.alignment: Qt.AlignHCenter; text: modelData.label; color: CurrentTheme.subtext; font.pixelSize: 9; }
          Text { Layout.alignment: Qt.AlignHCenter; text: modelData.glyph; font.family: Theme.iconFontFamily; font.pixelSize: 15; color: CurrentTheme.text; }
          Text { Layout.alignment: Qt.AlignHCenter; text: modelData.max + "°  " + modelData.min + "°"; color: CurrentTheme.subtext; font.pixelSize: 9; }
        }
      }
    }

    Flickable {
      visible: root.showHourly && Services.WeatherService.hourly.length > 0;
      Layout.fillWidth: true;
      implicitHeight: visible ? 54 : 0;
      contentWidth: hourRow.width;
      clip: true;
      flickableDirection: Flickable.HorizontalFlick;
      boundsBehavior: Flickable.StopAtBounds;

      Row {
        id: hourRow;
        spacing: 15;
        Repeater {
          model: Services.WeatherService.hourly;
          delegate: Column {
            required property var modelData;
            spacing: 2;
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.hour; color: CurrentTheme.subtext; font.pixelSize: 9; }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.glyph; font.family: Theme.iconFontFamily; font.pixelSize: 14; color: CurrentTheme.text; }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.temp + "°"; color: CurrentTheme.text; font.pixelSize: 10; }
          }
        }
      }
    }
  }

  HoverHandler { cursorShape: Qt.PointingHandCursor; }
  TapHandler { onTapped: root.showHourly = !root.showHourly; }
}
