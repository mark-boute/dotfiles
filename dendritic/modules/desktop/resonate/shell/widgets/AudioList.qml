import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Rows for the system panel's audio foldout: output devices, input devices
// and per-app volume. FoldCard owns the header.
ColumnLayout {
  id: root;
  readonly property var svc: Services.AudioService;
  spacing: 2;

  function glyphFor(n) {
    var p = n ? (n.properties || {}) : {};
    var s = ((p["device.api"] || "") + " " + (n ? n.name : "") + " " + root.svc.nodeLabel(n)).toLowerCase();
    if (/bluez|headphone|headset/.test(s)) return 0xf02cb; // md-headphones
    if (/hdmi|displayport|monitor/.test(s)) return 0xf0379; // md-monitor
    if (/mic|source|input/.test(s)) return 0xf036c;        // md-microphone
    return 0xf04c3;                                         // md-speaker
  }

  component Header: Text {
    Layout.fillWidth: true;
    Layout.topMargin: 10;
    Layout.leftMargin: 6;
    Layout.bottomMargin: 4;
    color: CurrentTheme.subtext;
    font.pixelSize: 11; font.weight: Font.Bold;
  }

  Repeater {
    model: root.svc.sinks;
    delegate: FoldRow {
      required property var modelData;
      readonly property bool current: root.svc.isDefaultSink(modelData);
      Layout.fillWidth: true;
      name: root.svc.nodeLabel(modelData);
      bold: current;
      glyph: String.fromCodePoint(root.glyphFor(modelData));
      trailGlyph: current ? String.fromCodePoint(0xf012c) : ""; // md-check
      trailColor: CurrentTheme.text;
      onTapped: root.svc.setSink(modelData);
    }
  }

  Header {
    visible: root.svc.sources.length > 0;
    text: "Input";
  }

  Repeater {
    model: root.svc.sources;
    delegate: FoldRow {
      required property var modelData;
      readonly property bool current: root.svc.isDefaultSource(modelData);
      Layout.fillWidth: true;
      name: root.svc.nodeLabel(modelData);
      bold: current;
      glyph: String.fromCodePoint(0xf036c);
      trailGlyph: current ? String.fromCodePoint(0xf012c) : "";
      trailColor: CurrentTheme.text;
      onTapped: root.svc.setSource(modelData);
    }
  }

  Header {
    visible: root.svc.streams.length > 0;
    text: "Apps";
  }

  Repeater {
    model: root.svc.streams;
    delegate: RowLayout {
      required property var modelData;
      Layout.fillWidth: true;
      Layout.leftMargin: 6;
      Layout.bottomMargin: 4;
      spacing: 8;

      Text {
        Layout.preferredWidth: 84;
        text: root.svc.nodeLabel(modelData);
        color: CurrentTheme.text;
        font.pixelSize: 11;
        elide: Text.ElideRight;
      }
      LevelSlider {
        Layout.fillWidth: true;
        implicitHeight: 28;
        value: modelData.audio ? modelData.audio.volume : 0;
        onMoved: (f) => root.svc.setNodeVolume(modelData, f);
      }
    }
  }
}
