import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Output-device picker + per-app volume, for the power panel's audio dropdown.
ColumnLayout {
  id: root;
  readonly property var svc: Services.AudioService;
  spacing: 6;

  Text {
    text: "Output";
    color: CurrentTheme.subtext;
    font.pixelSize: 11; font.weight: Font.DemiBold;
  }

  Repeater {
    model: root.svc.sinks;
    delegate: Rectangle {
      id: sinkRow;
      required property var modelData;
      readonly property bool current: root.svc.isDefaultSink(modelData);
      Layout.fillWidth: true;
      implicitHeight: 30;
      radius: 8;
      color: current ? Qt.rgba(CurrentTheme.accent.r, CurrentTheme.accent.g, CurrentTheme.accent.b, 0.16)
        : (dHover.hovered ? CurrentTheme.surfaceHover : "transparent");

      RowLayout {
        anchors.fill: parent;
        anchors.leftMargin: 8;
        anchors.rightMargin: 10;
        spacing: 8;
        Text {
          text: String.fromCodePoint(sinkRow.current ? 0xf043e : 0xf043d); // radio checked/blank
          font.family: Theme.iconFontFamily;
          font.pixelSize: 13;
          color: sinkRow.current ? CurrentTheme.accent : CurrentTheme.subtext;
        }
        Text {
          Layout.fillWidth: true;
          text: root.svc.nodeLabel(sinkRow.modelData);
          color: CurrentTheme.text;
          font.pixelSize: 12;
          font.weight: sinkRow.current ? Font.DemiBold : Font.Normal;
          elide: Text.ElideRight;
        }
      }
      HoverHandler { id: dHover; cursorShape: Qt.PointingHandCursor; }
      TapHandler { onTapped: root.svc.setSink(sinkRow.modelData); }
    }
  }

  Text {
    visible: root.svc.streams.length > 0;
    Layout.topMargin: 4;
    text: "Apps";
    color: CurrentTheme.subtext;
    font.pixelSize: 11; font.weight: Font.DemiBold;
  }

  Repeater {
    model: root.svc.streams;
    delegate: RowLayout {
      required property var modelData;
      Layout.fillWidth: true;
      spacing: 8;

      Text {
        Layout.preferredWidth: 90;
        text: root.svc.nodeLabel(modelData);
        color: CurrentTheme.text;
        font.pixelSize: 11;
        elide: Text.ElideRight;
      }
      SliderPill {
        Layout.fillWidth: true;
        value: modelData.audio ? modelData.audio.volume : 0;
        valueLabel: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%";
        onMoved: (f) => root.svc.setNodeVolume(modelData, f);
      }
    }
  }
}
