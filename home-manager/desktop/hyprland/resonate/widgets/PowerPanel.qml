import QtQuick
import QtQuick.Layouts
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
Item {
  id: panel;

  readonly property int contentWidth: 320;

  // Pushed by ResizeBox — true while this panel is actually open/closing.
  // Gates the power-draw sampler so it isn't spawning a probe every few
  // seconds (and, when the dGPU is briefly awake, poking nvidia) 24/7.
  property bool panelActive: false;

  // Which device dropdown is open under the Wi-Fi / Bluetooth tiles ("wifi",
  // "bt", or ""). Opening one triggers that service's scan.
  property string openSection: "";
  onOpenSectionChanged: {
    if (openSection === "wifi") Services.NetworkService.scan();
    else if (openSection === "bt") Services.BluetoothService.scan();
  }

  // Keep the open dropdown's list fresh.
  Timer {
    interval: 8000; repeat: true;
    running: panel.openSection !== "";
    onTriggered: {
      if (panel.openSection === "wifi") Services.NetworkService.refresh();
      else if (panel.openSection === "bt") Services.BluetoothService.refresh();
    }
  }

  implicitWidth: layout.implicitWidth + Theme.defaultMargin * 2;
  implicitHeight: Math.min(layout.implicitHeight, Theme.maxPanelContentHeight) + Theme.defaultMargin * 2;

  readonly property color batteryColor: CurrentTheme.batteryColor(UPower.displayDevice.percentage);

  // Poweroff / restart / hibernate / logout / lock. All but lock confirm
  // inline (pendingSession -> the confirm bar under the row); lock fires
  // straight away. Raw commands rather than hyprshutdown — its own fullscreen
  // confirm overlay would just double up with ours, and its --post-cmd
  // wrapping was what stopped logout working.
  readonly property var sessionModel: [
    { glyph: 0xf0425, danger: true,  confirm: "Power off?", cmd: "systemctl poweroff" },
    { glyph: 0xf0709, danger: false, confirm: "Restart?",   cmd: "systemctl reboot" },
    { glyph: 0xf0717, danger: false, confirm: "Hibernate?", cmd: "systemctl hibernate" }, // snowflake
    { glyph: 0xf0343, danger: false, confirm: "Log out?",   cmd: "hyprctl dispatch 'hl.dsp.exit()'" },
    { glyph: 0xf033e, danger: false, confirm: "",            cmd: "hyprctl dispatch 'hl.dsp.global(\"quickshell:Lock\")'" },
  ];
  property int pendingSession: -1; // index into sessionModel awaiting confirm, -1 = none

  Process { id: sessionProc; }
  function sessionAction(cmd) {
    sessionProc.command = ["sh", "-c", cmd];
    sessionProc.running = true;
  }

  onPanelActiveChanged: {
    Services.PowerUsageService.panelOpen = panelActive;
    if (!panelActive)
      panel.pendingSession = -1;
  }

  // Just the content now — the painted surface (fill + shadow + the outward
  // curve into the connecting strip) is BarSurface, one shared shape drawn
  // once for the whole bar in Bar.qml.
  Item {
    anchors.fill: parent;

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

        // --- Battery level: bar takes the row, percentage only what it needs ---
        RowLayout {
          Layout.preferredWidth: panel.contentWidth;
          spacing: Theme.defaultSpacing;

          Rectangle {
            id: batteryBarTrack;
            Layout.fillWidth: true;
            Layout.alignment: Qt.AlignVCenter;
            implicitHeight: 6;
            radius: height / 2;
            color: CurrentTheme.backgroundGlass;

            Rectangle {
              width: parent.width * UPower.displayDevice.percentage;
              height: parent.height;
              radius: parent.radius;
              color: panel.batteryColor;

              Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: 180 } }
            }
          }

          Text {
            text: Math.round(UPower.displayDevice.percentage * 100) + "%";
            color: CurrentTheme.text;
            font.pixelSize: 11;
            font.weight: Font.DemiBold;
          }
        }

        // --- Session actions ---
        RowLayout {
          Layout.preferredWidth: panel.contentWidth;
          spacing: Theme.defaultSpacing;

          Repeater {
            model: panel.sessionModel;

            delegate: Rectangle {
              required property var modelData;
              required property int index;
              readonly property bool pending: panel.pendingSession === index;
              Layout.fillWidth: true;
              implicitHeight: 40;
              radius: 10;
              color: pending
                ? Qt.rgba(CurrentTheme.accent.r, CurrentTheme.accent.g, CurrentTheme.accent.b, 0.18)
                : (sessionHover.hovered ? CurrentTheme.surfaceHover : CurrentTheme.backgroundGlass);
              border.width: 1;
              border.color: pending ? CurrentTheme.accent : CurrentTheme.border;

              Behavior on color { ColorAnimation { duration: 100 } }

              Text {
                anchors.centerIn: parent;
                text: String.fromCodePoint(modelData.glyph);
                font.family: Theme.iconFontFamily;
                font.pixelSize: Theme.iconSize;
                color: modelData.danger
                  ? (sessionHover.hovered ? CurrentTheme.danger : CurrentTheme.text)
                  : CurrentTheme.text;
              }

              HoverHandler { id: sessionHover; cursorShape: Qt.PointingHandCursor; }
              TapHandler {
                onTapped: {
                  if (modelData.confirm !== "")
                    panel.pendingSession = (panel.pendingSession === index ? -1 : index);
                  else
                    panel.sessionAction(modelData.cmd);
                }
              }
            }
          }
        }

        // Inline confirmation for the destructive session actions — opens
        // right under the row, Cancel on the left so Confirm is never where
        // the button you just tapped was.
        Rectangle {
          id: sessionConfirm;
          Layout.preferredWidth: panel.contentWidth;
          readonly property var act: panel.pendingSession >= 0 ? panel.sessionModel[panel.pendingSession] : null;
          visible: act !== null;
          implicitHeight: visible ? 40 : 0;
          radius: 10;
          color: CurrentTheme.backgroundGlass;
          clip: true;

          RowLayout {
            anchors.fill: parent;
            anchors.leftMargin: 12;
            anchors.rightMargin: 6;
            spacing: 6;

            Text {
              Layout.fillWidth: true;
              text: sessionConfirm.act ? sessionConfirm.act.confirm : "";
              color: CurrentTheme.text;
              font.pixelSize: 12;
              font.weight: Font.DemiBold;
            }

            Rectangle {
              Layout.preferredWidth: 66;
              Layout.preferredHeight: 28;
              radius: 8;
              color: cancelHover.hovered ? CurrentTheme.surfaceHover : "transparent";
              border.width: 1;
              border.color: CurrentTheme.border;
              Text { anchors.centerIn: parent; text: "Cancel"; color: CurrentTheme.text; font.pixelSize: 11; }
              HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor; }
              TapHandler { onTapped: panel.pendingSession = -1; }
            }

            Rectangle {
              id: confirmBtn;
              Layout.preferredWidth: 66;
              Layout.preferredHeight: 28;
              radius: 8;
              readonly property color base: (sessionConfirm.act && sessionConfirm.act.danger)
                ? CurrentTheme.danger : CurrentTheme.accent;
              color: confirmHover.hovered ? base : Qt.rgba(base.r, base.g, base.b, 0.18);
              Behavior on color { ColorAnimation { duration: 100 } }
              Text {
                anchors.centerIn: parent;
                text: "Confirm";
                color: confirmHover.hovered ? CurrentTheme.background : confirmBtn.base;
                font.pixelSize: 11;
                font.weight: Font.DemiBold;
              }
              HoverHandler { id: confirmHover; cursorShape: Qt.PointingHandCursor; }
              TapHandler {
                onTapped: {
                  var cmd = sessionConfirm.act.cmd;
                  panel.pendingSession = -1;
                  panel.sessionAction(cmd);
                }
              }
            }
          }
        }

        // --- Power profile + dGPU: a label row over two half-width sliders ---
        RowLayout {
          Layout.preferredWidth: panel.contentWidth;
          spacing: Theme.defaultSpacing;

          Text {
            Layout.fillWidth: true;
            Layout.preferredWidth: 1;
            text: "Power profile";
            color: CurrentTheme.subtext;
            font.pixelSize: 11;
          }

          Item {
            Layout.fillWidth: true;
            Layout.preferredWidth: 1;
            implicitHeight: gpuLabel.implicitHeight;

            Row {
              id: gpuLabel;
              spacing: 6;

              Rectangle {
                id: gpuDot;
                anchors.verticalCenter: parent.verticalCenter;
                implicitWidth: 8; implicitHeight: 8; radius: 4;

                // Three states rather than a red/green binary: fully off
                // (suspended, in D3cold) reads as neutral grey, not red —
                // red should mean something's wrong, not "asleep and saving
                // power," which is the normal/good state here. "Idle" is
                // powered on (D0) but nothing currently has it open (the same
                // fd check PowerPanel's own sampler uses); "on" is powered on
                // and actually being used.
                readonly property string state:
                  !Services.GpuService.awake ? "off" :
                  Services.PowerUsageService.gpuAsleep ? "idle" : "on";
                color: gpuDot.state === "off" ? Theme.palette.overlay0 :
                  gpuDot.state === "idle" ? Theme.palette.blue :
                  CurrentTheme.success;
                Behavior on color { ColorAnimation { duration: 150 } }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter;
                text: "dGPU";
                color: CurrentTheme.subtext;
                font.pixelSize: 11;
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter;
                text: gpuDot.state === "off" ? "asleep" : gpuDot.state;
                color: CurrentTheme.text;
                font.pixelSize: 11;
                font.weight: Font.DemiBold;
              }
            }
          }
        }

        RowLayout {
          Layout.preferredWidth: panel.contentWidth;
          spacing: Theme.defaultSpacing;

          SegmentSlider {
            enabled: Services.PlatformProfileService.available;
            Layout.fillWidth: true;
            Layout.preferredWidth: 1;
            // "auto" isn't in PlatformProfileService.profiles (it's the
            // separate autoMode flag), so index 0 is reserved for it and the
            // fixed profiles fill the remaining slots in order.
            options: [
              { text: "A" },
              { glyph: 0xf032a }, // low-power
              { glyph: 0xf05d1 }, // balanced
              { glyph: 0xf0241 }, // performance
            ];
            currentIndex: {
              if (Services.PlatformProfileService.autoMode) return 0;
              var i = Services.PlatformProfileService.profiles.indexOf(Services.PlatformProfileService.profile);
              return i < 0 ? 0 : i + 1;
            }
            hintIndex: Services.PlatformProfileService.autoMode
              ? Services.PlatformProfileService.profiles.indexOf(Services.PlatformProfileService.profile) + 1 : -1;
            onPicked: (index) => {
              if (index === 0)
                Services.PlatformProfileService.autoMode = true;
              else
                Services.PlatformProfileService.set(Services.PlatformProfileService.profiles[index - 1]);
            }
          }

          // Auto: sleeps when idle. On: kept awake (e.g. to wake it before
          // plugging in the HDMI monitor). Dimmed without gpucontrol rights.
          SegmentSlider {
            enabled: Services.GpuService.controllable;
            Layout.fillWidth: true;
            Layout.preferredWidth: 1;
            options: [{ text: "A" }, { text: "On" }];
            currentIndex: Services.GpuService.forcedOn ? 1 : 0;
            onPicked: (index) => Services.GpuService.setForcedOn(index === 1);
          }
        }

        // --- Battery history + what is using power ---
        PowerUsage {
          Layout.preferredWidth: panel.contentWidth;
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
            status: Services.NetworkService.enabled
              ? (Services.NetworkService.activeSsid || "On") : "Off";
            active: Services.NetworkService.enabled;
            expandable: true;
            expanded: panel.openSection === "wifi";
            onTapped: Services.NetworkService.toggle();
            onToggleExpanded: panel.openSection = (panel.openSection === "wifi" ? "" : "wifi");
          }

          PowerTile {
            Layout.fillWidth: true;
            iconGlyph: String.fromCodePoint(0xf00af); // md-bluetooth
            label: "Bluetooth";
            status: Services.BluetoothService.enabled ? "On" : "Off";
            active: Services.BluetoothService.enabled;
            expandable: true;
            expanded: panel.openSection === "bt";
            onTapped: Services.BluetoothService.toggle();
            onToggleExpanded: panel.openSection = (panel.openSection === "bt" ? "" : "bt");
          }
        }

        // --- Wi-Fi / Bluetooth device dropdown ---
        Rectangle {
          Layout.preferredWidth: panel.contentWidth;
          visible: panel.openSection !== "";
          implicitHeight: visible ? sectionBody.implicitHeight + 20 : 0;
          radius: 12;
          color: CurrentTheme.backgroundGlass;
          clip: true;

          ColumnLayout {
            id: sectionBody;
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; }

            WifiList {
              Layout.fillWidth: true;
              visible: panel.openSection === "wifi";
            }
            BluetoothList {
              Layout.fillWidth: true;
              visible: panel.openSection === "bt";
            }
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
            color: Services.AudioService.muted ? CurrentTheme.backgroundGlass : CurrentTheme.accent;
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

          Rectangle {
            implicitWidth: 30; implicitHeight: 40;
            radius: 10;
            readonly property bool open: panel.openSection === "audio";
            color: open || audioChevHover.hovered ? CurrentTheme.surfaceHover : "transparent";
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
              anchors.centerIn: parent;
              text: String.fromCodePoint(parent.open ? 0xf0143 : 0xf0140); // chevron up/down
              font.family: Theme.iconFontFamily;
              font.pixelSize: Theme.iconSize;
              color: CurrentTheme.subtext;
            }
            HoverHandler { id: audioChevHover; cursorShape: Qt.PointingHandCursor; }
            TapHandler { onTapped: panel.openSection = (panel.openSection === "audio" ? "" : "audio"); }
          }
        }

        // --- Audio output / per-app dropdown ---
        Rectangle {
          Layout.preferredWidth: panel.contentWidth;
          visible: panel.openSection === "audio";
          implicitHeight: visible ? audioBody.implicitHeight + 20 : 0;
          radius: 12;
          color: CurrentTheme.backgroundGlass;
          clip: true;

          AudioList {
            id: audioBody;
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; }
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
            color: Services.BrightnessService.autoMode ? CurrentTheme.accent : CurrentTheme.backgroundGlass;
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

          // Screen-on (caffeine) toggle — right of the slider, same slot the
          // audio row's dropdown chevron sits in.
          Rectangle {
            id: cafBtn;
            implicitWidth: 40;
            implicitHeight: 40;
            radius: 20;
            readonly property bool on: Services.CaffeineService.active;
            color: on ? CurrentTheme.accent
              : (cafHover.hovered ? CurrentTheme.surfaceHover : CurrentTheme.backgroundGlass);
            border.width: on ? 0 : 1;
            border.color: CurrentTheme.border;
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent;
              text: String.fromCodePoint(0xf0176); // coffee
              font.family: Theme.iconFontFamily;
              font.pixelSize: 18;
              color: cafBtn.on ? CurrentTheme.background : CurrentTheme.text;
            }
            HoverHandler { id: cafHover; cursorShape: Qt.PointingHandCursor; }
            TapHandler { onTapped: Services.CaffeineService.toggle(); }
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
            color: Services.TemperatureService.autoMode ? CurrentTheme.accent : CurrentTheme.backgroundGlass;
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

          // Reads 0% = coolest, 100% = warmest (TemperatureService's own
          // fraction is the opposite — 0 = min/warmest K — hence 1 - x).
          SliderPill {
            Layout.fillWidth: true;
            temperature: true;
            value: (Services.TemperatureService.maxTempK - Services.TemperatureService.temperatureK) / (Services.TemperatureService.maxTempK - Services.TemperatureService.minTempK);
            valueLabel: Math.round((Services.TemperatureService.maxTempK - Services.TemperatureService.temperatureK) / (Services.TemperatureService.maxTempK - Services.TemperatureService.minTempK) * 100) + "%";
            onMoved: (fraction) => Services.TemperatureService.setTemperature(1 - fraction);
          }
        }
      }
    }
  }
}
