import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.UPower

import qs
import qs.services as Services

// Opened by clicking the power widget. Wi-Fi/Bluetooth state comes from
// NetworkService/BluetoothService (plain nmcli/bluetoothctl shell-outs
// under the hood, shared with the expanded status-icon row on the power
// widget itself). Audio goes through AudioService (shared with the bar's
// own mute button). Styled after a phone-style quick-settings sheet:
// status pills (accent-filled when on) plus a full-width slider pill.
Rectangle {
  id: panel;

  readonly property int contentWidth: 280;

  radius: 18;
  color: CurrentTheme.surface;
  border.width: 1;
  border.color: CurrentTheme.border;

  layer.enabled: true;
  layer.effect: MultiEffect {
    shadowEnabled: true;
    shadowColor: Theme.shadowColor;
    shadowBlur: Theme.shadowBlur;
    shadowVerticalOffset: Theme.shadowVerticalOffset;
  }

  implicitWidth: layout.implicitWidth + Theme.defaultMargin * 2;
  implicitHeight: Math.min(layout.implicitHeight, Theme.maxPanelContentHeight) + Theme.defaultMargin * 2;

  readonly property color batteryColor: {
    if (UPower.displayDevice.percentage <= 0.2) return CurrentTheme.danger;
    if (UPower.displayDevice.percentage <= 0.4) return CurrentTheme.warning;
    return CurrentTheme.success;
  }

  // Power-draw history for the graph below, last 5 minutes. Sampled
  // continuously (Timer.running: true, not tied to the panel's own
  // visibility) — this Loader's item is created once and never destroyed
  // as the panel opens/closes (see CenterWidget's panelLoader: `active`
  // only depends on panelContent being non-null, which it always is), so
  // sampling in the background means the graph already has real history
  // to show the moment the panel opens, instead of starting empty.
  readonly property int historyWindowMs: 5 * 60 * 1000;
  readonly property int sampleIntervalMs: 2000;
  property var history: []; // [{t, cpu, gpu}], oldest first

  // Average *total* draw (cpu+gpu per sample, then averaged) — not the
  // same computation as the graph's lo/mid/hi lines, which flatten cpu
  // and gpu into one combined list; averaging that flattened list would
  // blend two different signals into a number that doesn't correspond
  // to any real quantity, whereas total-draw-per-sample does.
  readonly property real avgWatts: {
    if (history.length === 0) return 0;
    var sum = 0;
    for (var i = 0; i < history.length; i++) sum += history[i].cpu + history[i].gpu;
    return sum / history.length;
  }

  // No true CPU-only reading is available without root (RAPL energy_uj
  // under /sys/class/powercap is root-only on this system) — this is
  // total system draw (via the battery's own discharge rate) minus GPU
  // draw, so "CPU" here really means "everything that isn't the GPU"
  // (display, disk, RAM, etc. included), not an isolated CPU package
  // reading. Chosen deliberately over adding a udev rule for real RAPL
  // access, to avoid a system-level permission change for this.
  property real gpuWatts: 0;
  property bool gpuAsleep: true;
  Process {
    id: gpuPowerProc;
    command: ["sh", "-c",
      "s=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null); " +
      "[ \"$s\" = D3cold ] && { echo asleep; exit; }; " +
      "ls -l /proc/[0-9]*/fd 2>/dev/null | grep -q /dev/nvidia0 " +
      "&& nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits || echo asleep"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        t = (t || "").trim();
        if (t === "asleep" || t === "") {
          panel.gpuAsleep = true;
          panel.gpuWatts = 0;
        } else {
          panel.gpuAsleep = false;
          panel.gpuWatts = parseFloat(t) || 0;
        }
        // Recorded here rather than in the Timer directly, so each
        // sample's cpu/gpu values come from the same moment instead of
        // gpu lagging behind by one interval while its process was
        // still running.
        var total = Math.abs(UPower.displayDevice.changeRate);
        var cpu = Math.max(0, total - panel.gpuWatts);
        var now = Date.now();
        var h = panel.history.concat([{ t: now, cpu: cpu, gpu: panel.gpuWatts }]);
        panel.history = h.filter(s => now - s.t <= panel.historyWindowMs);
        powerGraph.requestPaint();
      }
    }
  }
  Timer {
    interval: panel.sampleIntervalMs;
    repeat: true;
    running: true;
    triggeredOnStart: true;
    onTriggered: gpuPowerProc.running = true;
  }

  // Flickable rather than a plain centered ColumnLayout — see the same
  // comment in ControlPanel.qml. Drag-to-pan is Flickable's own default
  // behavior; the MouseArea below adds wheel support the same way
  // SliderPill.qml does (a bare WheelHandler was found not to fire here).
  Flickable {
    id: flick;
    anchors.fill: parent;
    anchors.margins: Theme.defaultMargin;
    contentWidth: layout.implicitWidth;
    contentHeight: layout.implicitHeight;
    clip: true;
    boundsBehavior: Flickable.StopAtBounds;

    MouseArea {
      anchors.fill: parent;
      acceptedButtons: Qt.NoButton;
      onWheel: (wheel) => {
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - wheel.angleDelta.y));
      }
    }

    ColumnLayout {
      id: layout;
      anchors.horizontalCenter: parent.horizontalCenter;
      spacing: Theme.defaultSpacing;
  
      // --- Battery level ---
      Rectangle {
        id: batteryBarTrack;
        Layout.preferredWidth: panel.contentWidth;
        implicitHeight: 6;
        radius: height / 2;
        color: CurrentTheme.background;
  
        Rectangle {
          width: parent.width * UPower.displayDevice.percentage;
          height: parent.height;
          radius: parent.radius;
          color: panel.batteryColor;
  
          Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }
  
      // --- Power draw graph (CPU/GPU, last 5 minutes) ---
      ColumnLayout {
        Layout.preferredWidth: panel.contentWidth;
        spacing: 4;
  
        RowLayout {
          Layout.fillWidth: true;
          spacing: Theme.defaultSpacing;
  
          Row {
            spacing: 4;
            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: CurrentTheme.accent; }
            Text { text: "CPU " + (panel.history.length > 0 ? panel.history[panel.history.length - 1].cpu.toFixed(1) : "0.0") + "W"; color: CurrentTheme.subtext; font.pixelSize: 11; }
          }
          Row {
            spacing: 4;
            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: CurrentTheme.warning; }
            Text { text: "GPU " + panel.gpuWatts.toFixed(1) + "W"; color: CurrentTheme.subtext; font.pixelSize: 11; }
          }
  
          Item { Layout.fillWidth: true; }
  
          Text { text: "5 min avg: " + panel.avgWatts.toFixed(1) + "W"; color: CurrentTheme.subtext; font.pixelSize: 10; }
        }
  
        // CurrentTheme.background — the same fill PowerTile uses for its
        // inactive/off state — rather than CurrentTheme.surface, so this
        // reads as its own little instrument panel against the rest of
        // the sheet. Radius is a fixed, moderate value rather than
        // height/2 like the pill controls use: this box is taller than
        // it is a "pill" shape, so full capsule rounding would look
        // exaggerated: same curve style, just less of it.
        Rectangle {
          Layout.preferredWidth: panel.contentWidth;
          implicitHeight: 60;
          radius: 10;
          color: CurrentTheme.background;
          clip: true;
  
          Canvas {
            id: powerGraph;
            anchors.fill: parent;
            anchors.margins: 6;
  
            readonly property real maxWatts: {
              var m = 10;
              for (var i = 0; i < panel.history.length; i++) {
                m = Math.max(m, panel.history[i].cpu, panel.history[i].gpu);
              }
              return m * 1.15;
            }
  
            onPaint: {
              var ctx = getContext("2d");
              ctx.reset();
              if (panel.history.length < 2) return;
  
              var now = Date.now();
              var w = width, h = height;
              function xFor(t) { return w * (1 - (now - t) / panel.historyWindowMs); }
              function yFor(watts) { return h - (watts / maxWatts) * h; }
  
              // Lowest/highest/center reference lines, over every plotted
              // value (both traces combined) rather than per-trace, so
              // there's one shared, easy-to-read scale rather than two.
              var allValues = [];
              for (var i = 0; i < panel.history.length; i++) {
                allValues.push(panel.history[i].cpu, panel.history[i].gpu);
              }
              var lo = Math.min.apply(null, allValues);
              var hi = Math.max.apply(null, allValues);
              var mid = (lo + hi) / 2;
  
              // CurrentTheme.text at low alpha, not a hardcoded white —
              // the background is now theme-aware (CurrentTheme.background,
              // per PowerTile's own inactive fill), and white would lose
              // most of its contrast on a light flavor like latte.
              var tc = CurrentTheme.text;
              ctx.font = "9px sans-serif";
              ctx.textBaseline = "middle";
              [lo, mid, hi].forEach(function(v) {
                var y = yFor(v);
                ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.15);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
                ctx.stroke();
                ctx.fillStyle = Qt.rgba(tc.r, tc.g, tc.b, 0.5);
                // Clamped so the highest/lowest labels (whose lines sit
                // right at the canvas edge) don't get cut off above/below
                // the visible area.
                ctx.fillText(v.toFixed(1) + "W", 2, Math.max(6, Math.min(h - 6, y - 5)));
              });
  
              function drawLine(key, color) {
                ctx.strokeStyle = color;
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                for (var i = 0; i < panel.history.length; i++) {
                  var s = panel.history[i];
                  var x = xFor(s.t), y = yFor(s[key]);
                  if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.stroke();
              }
  
              drawLine("gpu", CurrentTheme.warning);
              drawLine("cpu", CurrentTheme.accent);
            }
          }
        }
      }
  
      GridLayout {
        Layout.preferredWidth: panel.contentWidth;
        columns: 2;
        columnSpacing: Theme.defaultSpacing;
        rowSpacing: Theme.defaultSpacing;
  
        PowerTile {
          Layout.fillWidth: true;
          iconGlyph: String.fromCodePoint(0xf05a9); // md-wifi
          label: "Wi-Fi";
          status: Services.NetworkService.enabled ? "On" : "Off";
          active: Services.NetworkService.enabled;
          onTapped: Services.NetworkService.toggle();
        }
  
        PowerTile {
          Layout.fillWidth: true;
          iconGlyph: String.fromCodePoint(0xf00af); // md-bluetooth
          label: "Bluetooth";
          status: Services.BluetoothService.enabled ? "On" : "Off";
          active: Services.BluetoothService.enabled;
          onTapped: Services.BluetoothService.toggle();
        }
      }
  
      // --- Volume ---
      RowLayout {
        Layout.preferredWidth: panel.contentWidth;
        Layout.topMargin: Theme.defaultSpacing / 2;
        spacing: Theme.defaultSpacing;
  
        // Mute button — separate from the slider track so its icon never
        // has to sit on top of the moving fill.
        Rectangle {
          implicitWidth: 40;
          implicitHeight: 40;
          radius: 20;
          color: Services.AudioService.muted ? CurrentTheme.background : CurrentTheme.accent;
          border.width: Services.AudioService.muted ? 1 : 0;
          border.color: CurrentTheme.border;
          opacity: Services.AudioService.available ? 1 : 0.4;
  
          Behavior on color { ColorAnimation { duration: 140 } }
  
          Text {
            anchors.centerIn: parent;
            text: Services.AudioService.iconGlyph;
            font.family: Theme.iconFontFamily;
            font.pixelSize: 18;
            color: Services.AudioService.muted ? CurrentTheme.text : CurrentTheme.background;
          }
  
          TapHandler {
            enabled: Services.AudioService.available;
            onTapped: Services.AudioService.toggleMute();
          }
        }
  
        SliderPill {
          Layout.fillWidth: true;
          enabled: Services.AudioService.available;
          value: Services.AudioService.volume;
          valueLabel: Services.AudioService.muted ? "Muted" : Math.round(Services.AudioService.volume * 100) + "%";
          fillColor: Services.AudioService.muted ? CurrentTheme.subtext : CurrentTheme.accent;
          onMoved: (fraction) => Services.AudioService.setVolume(fraction);
        }
      }
  
      // --- Brightness ---
      RowLayout {
        Layout.preferredWidth: panel.contentWidth;
        spacing: Theme.defaultSpacing;
  
        // Tapping toggles auto mode — accent-filled while it's on (plus
        // the "A" badge below), same fill convention as the mute button
        // above. Turning it back on also applies the curve immediately
        // (applyAutoCurves), rather than leaving the old manual value
        // sitting there until the next minute's tick.
        Rectangle {
          implicitWidth: 40;
          implicitHeight: 40;
          radius: 20;
          color: Services.BrightnessService.autoMode ? CurrentTheme.accent : CurrentTheme.background;
          border.width: Services.BrightnessService.autoMode ? 0 : 1;
          border.color: CurrentTheme.border;
  
          Behavior on color { ColorAnimation { duration: 140 } }
  
          Text {
            anchors.centerIn: parent;
            text: String.fromCodePoint(0xf05a8); // md-white_balance_sunny
            font.family: Theme.iconFontFamily;
            font.pixelSize: 18;
            color: Services.BrightnessService.autoMode ? CurrentTheme.background : CurrentTheme.text;
          }
  
          Rectangle {
            visible: Services.BrightnessService.autoMode;
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: -2; bottomMargin: -2; }
            width: 14;
            height: 14;
            radius: 7;
            color: CurrentTheme.surface;
            border.width: 1;
            border.color: CurrentTheme.border;
  
            Text {
              anchors.centerIn: parent;
              text: "A";
              font.pixelSize: 9;
              font.weight: Font.Bold;
              color: CurrentTheme.text;
            }
          }
  
          TapHandler {
            onTapped: {
              Services.BrightnessService.autoMode = !Services.BrightnessService.autoMode;
              if (Services.BrightnessService.autoMode) Services.BrightnessService.applyAutoCurve();
            }
          }
        }
  
        SliderPill {
          Layout.fillWidth: true;
          value: Services.BrightnessService.brightness;
          valueLabel: Math.round(Services.BrightnessService.brightness * 100) + "%";
          onMoved: (fraction) => Services.BrightnessService.setBrightness(fraction);
        }
      }
  
      // --- Color temperature ---
      RowLayout {
        Layout.preferredWidth: panel.contentWidth;
        spacing: Theme.defaultSpacing;
  
        Rectangle {
          implicitWidth: 40;
          implicitHeight: 40;
          radius: 20;
          color: Services.TemperatureService.autoMode ? CurrentTheme.accent : CurrentTheme.background;
          border.width: Services.TemperatureService.autoMode ? 0 : 1;
          border.color: CurrentTheme.border;
  
          Behavior on color { ColorAnimation { duration: 140 } }
  
          Text {
            anchors.centerIn: parent;
            text: String.fromCodePoint(0xf050f); // md-thermometer
            font.family: Theme.iconFontFamily;
            font.pixelSize: 18;
            color: Services.TemperatureService.autoMode ? CurrentTheme.background : CurrentTheme.text;
          }
  
          Rectangle {
            visible: Services.TemperatureService.autoMode;
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: -2; bottomMargin: -2; }
            width: 14;
            height: 14;
            radius: 7;
            color: CurrentTheme.surface;
            border.width: 1;
            border.color: CurrentTheme.border;
  
            Text {
              anchors.centerIn: parent;
              text: "A";
              font.pixelSize: 9;
              font.weight: Font.Bold;
              color: CurrentTheme.text;
            }
          }
  
          TapHandler {
            onTapped: {
              Services.TemperatureService.autoMode = !Services.TemperatureService.autoMode;
              if (Services.TemperatureService.autoMode) Services.TemperatureService.applyAutoCurve();
            }
          }
        }
  
        SliderPill {
          Layout.fillWidth: true;
          value: (Services.TemperatureService.temperatureK - Services.TemperatureService.minTempK) / (Services.TemperatureService.maxTempK - Services.TemperatureService.minTempK);
          valueLabel: Services.TemperatureService.temperatureK + "K";
          onMoved: (fraction) => Services.TemperatureService.setTemperature(fraction);
        }
      }
    }
  }
}
