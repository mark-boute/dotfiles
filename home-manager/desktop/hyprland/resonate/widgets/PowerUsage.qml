import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

import qs
import qs.services as Services

// The power panel's usage section: battery draw since unplugged (always
// shown), and an expandable Apps / Devices breakdown. All data and its
// caveats live in PowerUsageService.
ColumnLayout {
  id: usage;
  spacing: 6;

  readonly property var svc: Services.PowerUsageService;

  function fmtDur(secs) {
    var h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
    return h > 0 ? h + "h " + m + "m" : m + "m";
  }
  function clock(ms) { return Qt.formatTime(new Date(ms), "hh:mm"); }

  readonly property var session: svc.session;
  readonly property bool live: UPower.onBattery;
  readonly property real sessionSecs: session.length
    ? (live ? Date.now() / 1000 : session[session.length - 1].t) - session[0].t : 0;
  readonly property real sessionAvg: {
    if (!session.length) return 0;
    var s = 0;
    for (var i = 0; i < session.length; i++) s += session[i].w;
    return s / session.length;
  }

  onSessionChanged: graph.requestPaint();

  // --- header: session length | average + time left ---
  RowLayout {
    Layout.fillWidth: true;
    spacing: Theme.defaultSpacing;

    Text {
      Layout.fillWidth: true;
      text: usage.session.length
        ? (usage.live ? "On battery · " : "Last on battery · ") + usage.fmtDur(usage.sessionSecs)
        : "Battery";
      color: CurrentTheme.subtext;
      font.pixelSize: 11;
    }
    Text {
      text: {
        var parts = [];
        if (usage.session.length) parts.push("avg " + usage.sessionAvg.toFixed(1) + " W");
        var d = UPower.displayDevice;
        if (usage.live && d.timeToEmpty > 0) parts.push(usage.fmtDur(d.timeToEmpty) + " left");
        else if (!usage.live && d.state === UPowerDeviceState.Charging && d.timeToFull > 0)
          parts.push(usage.fmtDur(d.timeToFull) + " to full");
        return parts.join(" · ");
      }
      color: CurrentTheme.text;
      font.pixelSize: 11;
      font.weight: Font.DemiBold;
    }
  }

  // --- battery draw graph ---
  Rectangle {
    Layout.fillWidth: true;
    implicitHeight: 60;
    radius: 10;
    color: CurrentTheme.backgroundGlass;
    clip: true;

    Text {
      anchors.centerIn: parent;
      visible: usage.session.length < 2;
      text: "No time on battery recorded yet";
      color: CurrentTheme.subtext;
      font.pixelSize: 11;
    }

    Canvas {
      id: graph;
      anchors.fill: parent;
      anchors.margins: 6;

      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var pts = usage.session;
        if (pts.length < 2) return;

        var t0 = pts[0].t, t1 = pts[pts.length - 1].t;
        var lo = Infinity, hi = 0;
        for (var i = 0; i < pts.length; i++) { lo = Math.min(lo, pts[i].w); hi = Math.max(hi, pts[i].w); }
        var top = Math.max(10, hi) * 1.15;
        var w = width, h = height;
        function xFor(t) { return w * (t - t0) / Math.max(1, t1 - t0); }
        function yFor(v) { return h - (v / top) * h; }

        // Lowest/middle/highest reference lines with their values.
        var tc = CurrentTheme.text;
        ctx.font = "9px sans-serif";
        ctx.textBaseline = "middle";
        var lastLabelY = -Infinity;
        [hi, (lo + hi) / 2, lo].forEach(function (v) {
          var y = yFor(v);
          ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.15);
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(0, y);
          ctx.lineTo(w, y);
          ctx.stroke();
          // Top-down; a label that would overlap the one above is skipped.
          var ly = Math.max(6, Math.min(h - 6, y - 5));
          if (ly - lastLabelY < 11) return;
          lastLabelY = ly;
          ctx.fillStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.5);
          ctx.fillText(v.toFixed(1) + "W", 2, ly);
        });

        var ac = CurrentTheme.accent;
        ctx.beginPath();
        ctx.moveTo(xFor(pts[0].t), h);
        for (var j = 0; j < pts.length; j++) ctx.lineTo(xFor(pts[j].t), yFor(pts[j].w));
        ctx.lineTo(xFor(t1), h);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(ac.r, ac.g, ac.b, 0.15);
        ctx.fill();

        ctx.beginPath();
        for (var k = 0; k < pts.length; k++) {
          if (k === 0) ctx.moveTo(xFor(pts[k].t), yFor(pts[k].w));
          else ctx.lineTo(xFor(pts[k].t), yFor(pts[k].w));
        }
        ctx.strokeStyle = ac;
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
    }
  }

  // --- details toggle ---
  Item {
    Layout.fillWidth: true;
    implicitHeight: detailsRow.implicitHeight + 4;

    Row {
      id: detailsRow;
      anchors.horizontalCenter: parent.horizontalCenter;
      anchors.verticalCenter: parent.verticalCenter;
      spacing: 4;
      Text {
        anchors.verticalCenter: parent.verticalCenter;
        text: "What's using power";
        color: detailsHover.hovered ? CurrentTheme.text : CurrentTheme.subtext;
        font.pixelSize: 11;
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter;
        text: String.fromCodePoint(usage.svc.detailsOpen ? 0xf0143 : 0xf0140); // chevron up/down
        font.family: Theme.iconFontFamily;
        font.pixelSize: 14;
        color: detailsHover.hovered ? CurrentTheme.text : CurrentTheme.subtext;
      }
    }
    HoverHandler { id: detailsHover; cursorShape: Qt.PointingHandCursor; }
    TapHandler { onTapped: usage.svc.detailsOpen = !usage.svc.detailsOpen; }
  }

  // --- details: tabs, window, list ---
  ColumnLayout {
    Layout.fillWidth: true;
    visible: usage.svc.detailsOpen;
    spacing: 6;

    RowLayout {
      Layout.fillWidth: true;
      spacing: Theme.defaultSpacing;

      SegmentSlider {
        Layout.fillWidth: true;
        Layout.preferredWidth: 1;
        options: [{ text: "Apps" }, { text: "Devices" }];
        currentIndex: usage.svc.tab === "apps" ? 0 : 1;
        onPicked: (index) => usage.svc.tab = index === 0 ? "apps" : "devices";
      }
      SegmentSlider {
        Layout.fillWidth: true;
        Layout.preferredWidth: 1;
        options: [{ text: "1 min" }, { text: "Battery" }];
        currentIndex: usage.svc.range === "minute" ? 0 : 1;
        onPicked: (index) => usage.svc.range = index === 0 ? "minute" : "battery";
      }
    }

    Text {
      Layout.fillWidth: true;
      wrapMode: Text.WordWrap;
      color: CurrentTheme.subtext;
      font.pixelSize: 10;
      text: {
        var s = usage.svc;
        var when;
        if (s.windowSecs > 0)
          when = s.range === "minute"
            ? "Last " + Math.round(s.windowSecs) + " s"
            : "Since " + usage.clock(s.windowStart) + (usage.live ? "" : ", until plugged in");
        else
          when = s.range === "battery" && !s.battSnap
            ? "No time on battery since resonate started" : "Collecting…";
        return when + (usage.svc.tab === "apps" && s.windowSecs > 0
          ? " · W ≈ each app's share of CPU + iGPU power" : "");
      }
    }

    Repeater {
      model: usage.svc.tab === "apps" ? usage.svc.apps : [];
      delegate: RowLayout {
        required property var modelData;
        Layout.fillWidth: true;
        spacing: Theme.defaultSpacing;

        Text {
          Layout.fillWidth: true;
          text: modelData.name;
          elide: Text.ElideRight;
          color: CurrentTheme.text;
          font.pixelSize: 11;
        }
        Text {
          text: "cpu " + Math.round(modelData.cpu) + "%" + (modelData.gpu >= 0.5 ? " · gpu " + Math.round(modelData.gpu) + "%" : "");
          color: CurrentTheme.subtext;
          font.pixelSize: 10;
        }
        Text {
          Layout.preferredWidth: 46;
          horizontalAlignment: Text.AlignRight;
          text: modelData.watts === null ? "—" : "≈" + modelData.watts.toFixed(1) + " W";
          color: CurrentTheme.text;
          font.pixelSize: 11;
          font.weight: Font.DemiBold;
        }
      }
    }

    Repeater {
      model: usage.svc.tab === "devices" ? usage.svc.devices : [];
      delegate: RowLayout {
        required property var modelData;
        Layout.fillWidth: true;
        // Unmeasured devices are indented under the "Rest" row they make up.
        Layout.leftMargin: modelData.measured ? 0 : 12;
        spacing: Theme.defaultSpacing;

        Text {
          Layout.fillWidth: true;
          text: modelData.name;
          wrapMode: Text.WordWrap;
          color: modelData.measured ? CurrentTheme.text : CurrentTheme.subtext;
          font.pixelSize: 11;
        }
        Text {
          text: modelData.detail;
          color: CurrentTheme.subtext;
          font.pixelSize: 10;
        }
        Text {
          horizontalAlignment: Text.AlignRight;
          text: modelData.value;
          color: modelData.measured ? CurrentTheme.text : CurrentTheme.subtext;
          font.pixelSize: 11;
          font.weight: modelData.measured ? Font.DemiBold : Font.Normal;
        }
      }
    }
  }
}
