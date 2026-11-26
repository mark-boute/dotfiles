import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

import qs
import qs.services as Services

// The system panel's Power page: power mode and the dGPU, recent draw on a
// light/normal/heavy scale, and what is using it (apps, or parts: measured
// processor draw against the estimated rest, plus which devices are awake).
ColumnLayout {
  id: page;
  spacing: 12;

  signal back();

  readonly property var usage: Services.PowerUsageService;
  readonly property var profiles: Services.PlatformProfileService;
  readonly property real percent: UPower.displayDevice.percentage;
  readonly property bool onBattery: UPower.onBattery;
  readonly property real drawW: onBattery ? Math.abs(UPower.displayDevice.changeRate) : 0;

  readonly property var modeNames: ({ "low-power": "Saver", "balanced": "Balanced", "performance": "Boost" });

  function watts(w) { return w === null || w === undefined ? "—" : w.toFixed(1) + " W"; }

  component Card: Rectangle {
    Layout.fillWidth: true;
    radius: 16;
    color: CurrentTheme.glass;
    border.width: 1;
    border.color: CurrentTheme.border;
  }

  // --- header ---
  RowLayout {
    Layout.fillWidth: true;
    Layout.preferredHeight: 30;
    spacing: 9;

    Rectangle {
      implicitWidth: 26; implicitHeight: 26; radius: 8;
      color: backHover.hovered ? CurrentTheme.chip : "transparent";
      Text {
        anchors.centerIn: parent;
        text: String.fromCodePoint(0xf0141); // md-chevron-left
        font.family: Theme.iconFontFamily;
        font.pixelSize: 18;
        color: CurrentTheme.text;
      }
      HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor; }
      TapHandler { onTapped: page.back(); }
    }
    Text {
      Layout.fillWidth: true;
      text: "Power";
      color: CurrentTheme.text;
      font.pixelSize: 15; font.weight: Font.Bold;
    }
    Text {
      text: Math.round(page.percent * 100) + "%" + (page.onBattery && page.drawW > 0 ? " · " + page.watts(page.drawW) : "");
      color: CurrentTheme.subtext;
      font.pixelSize: 11;
    }
  }

  // --- power mode + graphics card ---
  Card {
    implicitHeight: modeCol.implicitHeight + 24;

    ColumnLayout {
      id: modeCol;
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; }
      spacing: 0;

      RowLayout {
        Layout.fillWidth: true;
        Layout.preferredHeight: 16;
        Text {
          Layout.fillWidth: true;
          text: "Power mode";
          color: CurrentTheme.text;
          font.pixelSize: 12; font.weight: Font.Bold;
        }
        Text {
          text: page.profiles.autoMode ? "Auto is using " + (page.modeNames[page.profiles.profile] || page.profiles.profile) : "";
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
        }
      }

      Segmented {
        Layout.fillWidth: true;
        Layout.topMargin: 8;
        implicitHeight: 44;
        enabled: page.profiles.available;
        options: [
          { label: "Auto", glyph: 0xf0068 },     // md-auto-fix
          { label: "Saver", glyph: 0xf032a },    // md-leaf
          { label: "Balanced", glyph: 0xf05d1 }, // md-scale-balance
          { label: "Boost", glyph: 0xf0241 },    // md-flash
        ];
        currentIndex: page.profiles.autoMode ? 0 : page.profiles.profiles.indexOf(page.profiles.profile) + 1;
        dotIndex: page.profiles.autoMode ? page.profiles.profiles.indexOf(page.profiles.profile) + 1 : -1;
        onPicked: (i) => {
          if (i === 0) page.profiles.autoMode = true;
          else page.profiles.set(page.profiles.profiles[i - 1]);
        }
      }

      RowLayout {
        Layout.fillWidth: true;
        Layout.topMargin: 12;
        Layout.preferredHeight: 36;
        spacing: 10;

        ColumnLayout {
          Layout.fillWidth: true;
          spacing: 2;
          Text {
            text: "Graphics card";
            color: CurrentTheme.text;
            font.pixelSize: 12; font.weight: Font.Bold;
          }
          Text {
            text: !Services.GpuService.awake ? "dGPU asleep"
              : page.usage.gpuAsleep ? "dGPU awake, idle"
              : "dGPU in use" + (page.usage.gpuWatts ? " · " + page.watts(page.usage.gpuWatts) : "");
            color: CurrentTheme.subtext;
            font.pixelSize: 11;
          }
        }
        // Auto: sleeps when idle. On: kept awake (e.g. before plugging in the
        // HDMI monitor). Dimmed without gpucontrol rights.
        Segmented {
          implicitWidth: 112;
          implicitHeight: 32;
          enabled: Services.GpuService.controllable;
          options: [{ label: "Auto" }, { label: "On" }];
          currentIndex: Services.GpuService.forcedOn ? 1 : 0;
          onPicked: (i) => Services.GpuService.setForcedOn(i === 1);
        }
      }
    }
  }

  // --- power draw ---
  Card {
    id: drawCard;
    implicitHeight: drawCol.implicitHeight + 24;

    readonly property var session: page.usage.session;
    readonly property real minutes: session.length > 1
      ? Math.round(((page.onBattery ? Date.now() / 1000 : session[session.length - 1].t) - session[0].t) / 60) : 0;
    onSessionChanged: spark.requestPaint();

    ColumnLayout {
      id: drawCol;
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; }
      spacing: 8;

      RowLayout {
        Layout.fillWidth: true;
        Layout.preferredHeight: 16;
        Text {
          Layout.fillWidth: true;
          text: "Power draw";
          color: CurrentTheme.text;
          font.pixelSize: 12; font.weight: Font.Bold;
        }
        Text {
          text: drawCard.session.length < 2 ? ""
            : (page.onBattery ? "last " : "last run · ") + drawCard.minutes + " min";
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
        }
      }

      Item {
        Layout.fillWidth: true;
        implicitHeight: 40;

        Text {
          anchors.centerIn: parent;
          visible: page.usage.session.length < 2;
          text: "No time on battery recorded yet";
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
        }

        Canvas {
          id: spark;
          anchors.fill: parent;
          readonly property color ink: CurrentTheme.text;
          onInkChanged: requestPaint();
          onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var pts = page.usage.session;
            if (pts.length < 2) return;
            var w = width - 6, h = height - 6, ox = 2, oy = 3;
            var hi = 0;
            for (var i = 0; i < pts.length; i++) hi = Math.max(hi, pts[i].w);
            var top = Math.max(24, hi * 1.1);
            var t0 = pts[0].t, t1 = pts[pts.length - 1].t;
            function xf(t) { return ox + w * (t - t0) / Math.max(1, t1 - t0); }
            function yf(v) { return oy + h - (v / top) * h; }
            ctx.beginPath();
            for (var j = 0; j < pts.length; j++) {
              if (j === 0) ctx.moveTo(xf(pts[j].t), yf(pts[j].w));
              else ctx.lineTo(xf(pts[j].t), yf(pts[j].w));
            }
            ctx.lineJoin = "round";
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.7);
            ctx.stroke();
            ctx.lineTo(xf(t1), oy + h);
            ctx.lineTo(xf(t0), oy + h);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.08);
            ctx.fill();
            var last = pts[pts.length - 1];
            ctx.beginPath();
            ctx.arc(xf(last.t), yf(last.w), 2.5, 0, 2 * Math.PI);
            ctx.fillStyle = ink;
            ctx.fill();
          }
        }
      }

      // Light < 10 W, normal 10–20 W, heavy > 20 W, on a 0–30 W scale.
      Item {
        visible: page.onBattery && page.drawW > 0;
        Layout.fillWidth: true;
        implicitHeight: 24;

        id: meter;
        readonly property int zone: page.drawW < 10 ? 0 : page.drawW < 20 ? 1 : 2;

        Row {
          width: parent.width;
          height: 6;
          spacing: 2;
          Repeater {
            model: 3;
            Rectangle {
              required property int index;
              width: (parent.width - 4) / 3;
              height: 6;
              radius: 3;
              color: Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, index === 1 ? 0.26 : 0.14);
            }
          }
        }
        Rectangle {
          x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(page.drawW, 30) / 30 - width / 2));
          y: -3;
          width: 12; height: 12; radius: 6;
          color: CurrentTheme.text;
          border.width: 2;
          border.color: CurrentTheme.background;
          Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
        Row {
          y: 10;
          width: parent.width;
          Repeater {
            model: ["Light", "Normal", "Heavy"];
            Text {
              required property string modelData;
              required property int index;
              width: parent.width / 3;
              horizontalAlignment: index === 0 ? Text.AlignLeft : index === 1 ? Text.AlignHCenter : Text.AlignRight;
              text: modelData;
              font.pixelSize: 11;
              font.weight: meter.zone === index ? Font.Bold : Font.Normal;
              color: meter.zone === index ? CurrentTheme.text : CurrentTheme.subtext;
            }
          }
        }
      }

      Text {
        visible: !page.onBattery;
        Layout.fillWidth: true;
        text: "Plugged in · processor & graphics " + page.watts(page.usage.cpuWatts);
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
      }
    }
  }

  // --- what's using power ---
  Card {
    implicitHeight: useCol.implicitHeight + 24;

    ColumnLayout {
      id: useCol;
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; }
      spacing: 0;

      RowLayout {
        Layout.fillWidth: true;
        Layout.preferredHeight: 16;
        Text {
          Layout.fillWidth: true;
          text: "What's using power";
          color: CurrentTheme.text;
          font.pixelSize: 12; font.weight: Font.Bold;
        }
        Text {
          text: page.usage.range === "battery" ? "since unplugged" : "last minute";
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
          HoverHandler { cursorShape: Qt.PointingHandCursor; }
          TapHandler { onTapped: page.usage.range = page.usage.range === "battery" ? "minute" : "battery"; }
        }
      }

      Segmented {
        Layout.fillWidth: true;
        Layout.topMargin: 10;
        implicitHeight: 30;
        options: [{ label: "Apps" }, { label: "Parts" }];
        currentIndex: page.usage.tab === "devices" ? 1 : 0;
        onPicked: (i) => page.usage.tab = i === 1 ? "devices" : "apps";
      }

      Text {
        visible: page.usage.windowSecs === 0;
        Layout.fillWidth: true;
        Layout.topMargin: 12;
        text: page.usage.range === "battery" && !page.usage.battSnap ? "Nothing recorded since unplugging yet" : "Measuring…";
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
      }

      // Apps: share of the processor's draw, by busy time.
      ColumnLayout {
        visible: page.usage.tab === "apps" && page.usage.windowSecs > 0;
        Layout.fillWidth: true;
        Layout.topMargin: 12;
        spacing: 4;

        id: appsCol;
        readonly property real peak: page.usage.apps.length ? Math.max(0.1, page.usage.apps[0].busy) : 1;

        Repeater {
          model: page.usage.apps;
          RowLayout {
            required property var modelData;
            Layout.fillWidth: true;
            Layout.preferredHeight: 22;
            spacing: 8;
            Text {
              Layout.preferredWidth: 96;
              text: modelData.name;
              elide: Text.ElideRight;
              color: CurrentTheme.text;
              font.pixelSize: 11;
            }
            Item {
              Layout.fillWidth: true;
              implicitHeight: 6;
              Rectangle {
                anchors.fill: parent;
                radius: 3;
                color: Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.12);
              }
              Rectangle {
                width: Math.max(6, parent.width * modelData.busy / appsCol.peak);
                height: 6; radius: 3;
                color: Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.85);
              }
            }
            Text {
              Layout.preferredWidth: 48;
              horizontalAlignment: Text.AlignRight;
              text: modelData.watts === null ? Math.round(modelData.cpu) + "%" : "≈" + page.watts(modelData.watts);
              color: CurrentTheme.text;
              font.pixelSize: 11; font.weight: Font.Bold;
            }
          }
        }
      }

      // Parts: measured processor (and dGPU) draw against the estimated rest.
      ColumnLayout {
        id: partsCol;
        readonly property var p: page.usage.parts;
        readonly property real measured: p ? (p.cpu || 0) + (p.gpu || 0) : 0;
        readonly property real rest: p && p.total !== null ? Math.max(0, p.total - measured) : -1;

        visible: page.usage.tab === "devices" && p !== null;
        Layout.fillWidth: true;
        Layout.topMargin: 12;
        spacing: 0;

        HatchBar {
          Layout.fillWidth: true;
          implicitHeight: 14;
          radius: 7;
          fraction: partsCol.rest < 0 ? 1 : partsCol.measured / Math.max(0.1, partsCol.measured + partsCol.rest);
        }

        RowLayout {
          Layout.fillWidth: true;
          Layout.topMargin: 8;
          Layout.preferredHeight: 20;
          spacing: 8;
          HatchBar { implicitWidth: 10; implicitHeight: 10; radius: 3; fraction: 1; }
          Text {
            Layout.fillWidth: true;
            text: partsCol.p && partsCol.p.gpu ? "Processor & both GPUs" : "Processor & graphics";
            color: CurrentTheme.text;
            font.pixelSize: 11;
          }
          Text {
            text: page.watts(partsCol.measured);
            color: CurrentTheme.text;
            font.pixelSize: 11; font.weight: Font.Bold;
          }
        }
        RowLayout {
          Layout.fillWidth: true;
          Layout.topMargin: 4;
          Layout.preferredHeight: 20;
          spacing: 8;
          HatchBar { implicitWidth: 10; implicitHeight: 10; radius: 3; fraction: 0; }
          Text {
            Layout.fillWidth: true;
            text: "Screen, Wi-Fi, storage & rest";
            color: CurrentTheme.text;
            font.pixelSize: 11;
          }
          Text {
            text: partsCol.rest < 0 ? "on AC" : "≈ " + page.watts(partsCol.rest);
            color: partsCol.rest < 0 ? CurrentTheme.subtext : CurrentTheme.text;
            font.pixelSize: 11; font.weight: Font.Bold;
          }
        }

        Text {
          Layout.topMargin: 12;
          text: "Awake";
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
        }
        Flow {
          Layout.fillWidth: true;
          Layout.topMargin: 6;
          spacing: 6;
          Repeater {
            model: partsCol.p ? partsCol.p.awake : [];
            Rectangle {
              required property string modelData;
              width: awakeText.implicitWidth + 16; height: 24; radius: 12;
              color: CurrentTheme.chip;
              Text { id: awakeText; anchors.centerIn: parent; text: modelData; color: CurrentTheme.text; font.pixelSize: 11; }
            }
          }
        }

        Text {
          visible: partsCol.p && partsCol.p.asleep.length > 0;
          Layout.topMargin: 8;
          text: "Asleep";
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
        }
        Flow {
          Layout.fillWidth: true;
          Layout.topMargin: 6;
          spacing: 6;
          Repeater {
            model: partsCol.p ? partsCol.p.asleep : [];
            Rectangle {
              required property string modelData;
              width: asleepText.implicitWidth + 16; height: 24; radius: 12;
              color: "transparent";
              border.width: 1;
              border.color: CurrentTheme.chip;
              Text { id: asleepText; anchors.centerIn: parent; text: modelData; color: CurrentTheme.subtext; font.pixelSize: 11; }
            }
          }
        }
      }
    }
  }
}
