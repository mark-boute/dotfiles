import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

import qs
import qs.services as Services

// Opened from the power pill. Battery header with lock and a session row
// behind the power button; Wi-Fi / Bluetooth / Keep awake / Power tiles
// (Wi-Fi and Bluetooth fold a device list open between the tile rows);
// volume, brightness and warmth sliders (volume folds the audio devices
// open). The Power tile swaps the panel for PowerPage.
//
// The panel's size is always its settled target; Slot springs the bar shape
// toward it. Each foldout runs the same spring inside, so the content moves
// with the shape instead of jumping ahead of it.
Item {
  id: panel;

  readonly property int contentWidth: 320;

  // Pushed by Slot — true while the panel is open or fading out.
  property bool panelActive: false;
  signal closeRequested();

  // "" | "wifi" | "bt" | "audio" | "power"
  property string view: "";
  property bool session: false;
  // The network card keeps showing the last list while it folds shut.
  property string netList: "wifi";

  readonly property bool netOpen: view === "wifi" || view === "bt";
  readonly property bool audOpen: view === "audio";
  readonly property bool pageOpen: view === "power";
  // A session action (from the row below or a keybind) morphs the panel into
  // its confirm.
  readonly property bool confirming: panelActive && Services.SessionService.pending !== "";

  function toggleView(v) {
    panel.view = panel.view === v ? "" : v;
    if (v === "wifi" || v === "bt") panel.netList = v;
    if (panel.view === "wifi") Services.NetworkService.scan();
    else if (panel.view === "bt") Services.BluetoothService.scan();
  }

  onPanelActiveChanged: {
    Services.PowerUsageService.panelOpen = panelActive;
    if (!panelActive) {
      if (Services.SessionService.pending !== "") Services.SessionService.cancel();
      panel.view = "";
      panel.session = false;
    }
  }
  Binding {
    target: Services.PowerUsageService;
    property: "detailsOpen";
    value: panel.panelActive && panel.pageOpen;
  }

  // Keep the open list fresh.
  Timer {
    interval: 8000; repeat: true;
    running: panel.panelActive && panel.netOpen;
    onTriggered: {
      if (panel.view === "wifi") Services.NetworkService.refresh();
      else Services.BluetoothService.refresh();
    }
  }

  // --- sizes ---
  readonly property int sessionH: 68;
  readonly property int fixedMain: 48 + 12 + 56 + 8 + 56 + 12 + 40 + 8 + 40 + 8 + 40;
  readonly property real foldRoom: Theme.maxPanelContentHeight - fixedMain - (session ? sessionH : 0) - 8;
  readonly property real mainHeight: fixedMain + (session ? sessionH : 0)
    + (netOpen ? netCard.implicitHeight + 8 : 0)
    + (audOpen ? audCard.implicitHeight + 8 : 0);

  implicitWidth: confirming ? 430 : contentWidth + Theme.defaultMargin * 2;
  implicitHeight: confirming ? confirm.implicitHeight
    : (pageOpen ? powerPage.implicitHeight : mainHeight) + Theme.defaultMargin * 2;

  // --- inner springs, matching Slot's height axis ---
  component FoldSpring: Spring {
    live: panel.panelActive;
    growPeriod: 0.55; growDelay: 0.04;
    shrinkPeriod: 0.40;
  }
  FoldSpring { id: sessSpring; to: panel.session ? panel.sessionH : 0; }
  FoldSpring { id: netSpring; to: panel.netOpen ? netCard.implicitHeight + 8 : 0; }
  FoldSpring { id: audSpring; to: panel.audOpen ? audCard.implicitHeight + 8 : 0; }
  FoldSpring { id: pageSpring; to: panel.pageOpen ? 1 : 0; epsilon: 0.002; }

  function clamp01(v) { return Math.max(0, Math.min(1, v)); }
  // Foldout content fades in over the last part of the grow, out over the
  // first part of the shrink.
  function foldIn(spring, full) { return full > 0 ? clamp01((spring.value / full - 0.35) / 0.65) : 0; }
  function foldP(spring, full) { return full > 0 ? clamp01(spring.value / full) : 0; }

  readonly property real mainP: clamp01(1 - pageSpring.value / 0.45);
  readonly property real pageP: clamp01((pageSpring.value - 0.4) / 0.6);

  // Confirm hand-off: the outgoing content leaves fast, the incoming arrives
  // once the shape has mostly moved.
  property real normalOp: confirming ? 0 : 1;
  Behavior on normalOp {
    SequentialAnimation {
      PauseAnimation { duration: panel.confirming ? 0 : 160 }
      NumberAnimation { duration: panel.confirming ? 100 : 220; easing.type: Easing.OutCubic }
    }
  }
  property real confirmOp: confirming ? 1 : 0;
  Behavior on confirmOp {
    SequentialAnimation {
      PauseAnimation { duration: panel.confirming ? 160 : 0 }
      NumberAnimation { duration: panel.confirming ? 220 : 100; easing.type: Easing.OutCubic }
    }
  }

  // --- battery ---
  readonly property var bat: UPower.displayDevice;
  readonly property bool onBattery: UPower.onBattery;
  readonly property real drawW: onBattery ? Math.abs(bat.changeRate) : 0;
  readonly property real sessionAvg: {
    var s = Services.PowerUsageService.session;
    if (!onBattery || !s.length) return 0;
    var t = 0;
    for (var i = 0; i < s.length; i++) t += s[i].w;
    return t / s.length;
  }
  function fmtDur(secs) {
    var h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
    return h > 0 ? h + " h " + m + " min" : m + " min";
  }

  readonly property var sessionActions: [
    { label: "Restart",   glyph: 0xf0709, mode: "reboot" },
    { label: "Hibernate", glyph: 0xf0717, mode: "hibernate" },
    { label: "Log out",   glyph: 0xf0343, mode: "logout" },
    { label: "Power off", glyph: 0xf0425, mode: "poweroff" },
  ];

  readonly property var modeNames: ({ "low-power": "Saver", "balanced": "Balanced", "performance": "Boost" });

  component RoundButton: Rectangle {
    id: rb;
    property string glyph: "";
    property string label: "";
    property bool active: false;
    property real turn: 0;
    readonly property alias hovered: rbHover.hovered;
    signal clicked();
    implicitWidth: 40; implicitHeight: 40; radius: width / 2;
    color: active ? CurrentTheme.fill
      : rbHover.hovered ? Qt.tint(CurrentTheme.glass, Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.08))
      : CurrentTheme.glass;
    border.width: 1;
    border.color: CurrentTheme.border;
    Behavior on color { ColorAnimation { duration: 140 } }
    Text {
      anchors.centerIn: parent;
      text: rb.glyph !== "" ? rb.glyph : rb.label;
      rotation: 180 * rb.turn;
      font.family: rb.glyph !== "" ? Theme.iconFontFamily : Qt.application.font.family;
      font.pixelSize: rb.glyph !== "" ? 16 : 12;
      font.weight: Font.Bold;
      color: rb.active ? CurrentTheme.onFill : CurrentTheme.text;
    }
    HoverHandler { id: rbHover; cursorShape: Qt.PointingHandCursor; }
    TapHandler { onTapped: rb.clicked(); }
  }

  // ===== main view =====
  Column {
    id: main;
    x: Theme.defaultMargin;
    y: Theme.defaultMargin;
    width: panel.contentWidth;
    spacing: 0;
    visible: pageSpring.value < 0.999 && panel.normalOp > 0;
    opacity: panel.mainP * panel.normalOp;
    scale: 0.97 + 0.03 * panel.mainP;
    transformOrigin: Item.Top;

    // --- header ---
    Item {
      width: parent.width;
      height: 48 + sessSpring.value;
      clip: true;

      RowLayout {
        width: parent.width;
        height: 48;
        spacing: 10;

        Item {
          implicitWidth: 30; implicitHeight: 16;
          Rectangle {
            width: 27; height: 16; radius: 5;
            color: "transparent";
            border.width: 1.5;
            border.color: CurrentTheme.subtext;
          }
          Rectangle { x: 28; y: 5; width: 2; height: 6; radius: 1; color: CurrentTheme.subtext; }
          Rectangle {
            x: 3; y: 3; height: 10; radius: 2;
            width: Math.max(2, 21 * panel.bat.percentage);
            color: CurrentTheme.batteryColor(panel.bat.percentage);
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
          }
          Text {
            visible: !panel.onBattery;
            anchors.centerIn: parent;
            anchors.horizontalCenterOffset: -1;
            text: String.fromCodePoint(0xf140b); // md-lightning-bolt
            font.family: Theme.iconFontFamily;
            font.pixelSize: 11;
            color: CurrentTheme.text;
            style: Text.Outline;
            styleColor: CurrentTheme.background;
          }
        }

        ColumnLayout {
          Layout.fillWidth: true;
          Layout.minimumWidth: 0;
          spacing: 2;
          RowLayout {
            Layout.fillWidth: true;
            spacing: 8;
            Text {
              id: pctText;
              text: Math.round(panel.bat.percentage * 100) + "%";
              color: CurrentTheme.text;
              font.pixelSize: 20; font.weight: Font.Bold;
            }
            Text {
              Layout.alignment: Qt.AlignBaseline;
              visible: panel.onBattery && panel.drawW > 0;
              text: panel.drawW.toFixed(1) + "W";
              color: CurrentTheme.text;
              font.pixelSize: 13; font.weight: Font.Bold;
            }
            Text {
              Layout.alignment: Qt.AlignBaseline;
              Layout.fillWidth: true;
              Layout.minimumWidth: 0;
              visible: panel.sessionAvg > 0;
              elide: Text.ElideRight;
              text: panel.sessionAvg.toFixed(1) + "W avg";
              color: CurrentTheme.subtext;
              font.pixelSize: 11;
            }
          }
          Text {
            Layout.fillWidth: true;
            elide: Text.ElideRight;
            text: {
              var b = panel.bat;
              if (panel.onBattery)
                return (b.timeToEmpty > 0 ? panel.fmtDur(b.timeToEmpty) + " left · " : "") + "on battery";
              if (b.state === UPowerDeviceState.Charging)
                return (b.timeToFull > 0 ? panel.fmtDur(b.timeToFull) + " to full · " : "") + "charging";
              return "Plugged in";
            }
            color: CurrentTheme.subtext;
            font.pixelSize: 11;
          }
        }

        Row {
          spacing: 6;
          RoundButton {
            implicitWidth: 36; implicitHeight: 36;
            glyph: String.fromCodePoint(0xf033e); // md-lock
            onClicked: {
              panel.closeRequested();
              Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.global(\"quickshell:Lock\")"]);
            }
          }
          RoundButton {
            implicitWidth: 36; implicitHeight: 36;
            glyph: String.fromCodePoint(0xf0425); // md-power
            active: panel.session;
            onClicked: panel.session = !panel.session;
          }
        }
      }

      Row {
        y: 48 + 12 - (1 - panel.foldP(sessSpring, panel.sessionH)) * 6;
        width: parent.width;
        spacing: 8;
        opacity: panel.foldIn(sessSpring, panel.sessionH);
        visible: sessSpring.value > 0.5;

        Repeater {
          model: panel.sessionActions;
          Rectangle {
            id: sBtn;
            required property var modelData;
            width: (panel.contentWidth - 24) / 4;
            height: 56;
            radius: 14;
            color: sHover.hovered ? Qt.tint(CurrentTheme.glass, Qt.rgba(CurrentTheme.text.r, CurrentTheme.text.g, CurrentTheme.text.b, 0.08)) : CurrentTheme.glass;
            border.width: 1;
            border.color: CurrentTheme.border;
            Column {
              anchors.centerIn: parent;
              spacing: 5;
              Text {
                anchors.horizontalCenter: parent.horizontalCenter;
                text: String.fromCodePoint(sBtn.modelData.glyph);
                font.family: Theme.iconFontFamily;
                font.pixelSize: 18;
                color: CurrentTheme.text;
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter;
                text: sBtn.modelData.label;
                font.pixelSize: 11;
                color: CurrentTheme.text;
              }
            }
            HoverHandler { id: sHover; cursorShape: Qt.PointingHandCursor; }
            TapHandler {
              onTapped: Services.SessionService.request(sBtn.modelData.mode);
            }
          }
        }
      }
    }

    Item { width: 1; height: 12; }

    // --- tiles, with the network list folding open between the rows ---
    Row {
      width: parent.width;
      spacing: 8;

      SysTile {
        width: (parent.width - 8) / 2;
        glyph: String.fromCodePoint(Services.NetworkService.enabled ? 0xf05a9 : 0xf05aa); // md-wifi / -off
        title: "Wi-Fi";
        sub: !Services.NetworkService.enabled ? "Off" : (Services.NetworkService.activeSsid || "Not connected");
        on: Services.NetworkService.enabled;
        open: panel.view === "wifi";
        chevron: "down";
        chevronTurn: panel.netList === "wifi" ? panel.foldP(netSpring, netCard.implicitHeight + 8) : 0;
        onTapped: panel.toggleView("wifi");
        onIconTapped: Services.NetworkService.toggle();
      }
      SysTile {
        width: (parent.width - 8) / 2;
        readonly property var connected: Services.BluetoothService.devices.filter(d => d.connected);
        glyph: String.fromCodePoint(Services.BluetoothService.enabled ? 0xf00af : 0xf00b2); // md-bluetooth / -off
        title: "Bluetooth";
        sub: !Services.BluetoothService.enabled ? "Off"
          : connected.length === 0 ? "On"
          : connected[0].name + (connected.length > 1 ? " +" + (connected.length - 1) : "");
        on: Services.BluetoothService.enabled;
        open: panel.view === "bt";
        chevron: "down";
        chevronTurn: panel.netList === "bt" ? panel.foldP(netSpring, netCard.implicitHeight + 8) : 0;
        onTapped: panel.toggleView("bt");
        onIconTapped: Services.BluetoothService.toggle();
      }
    }

    Item {
      width: parent.width;
      height: netSpring.value;
      clip: true;
      visible: height > 0.5;

      FoldCard {
        id: netCard;
        y: 8 - (1 - panel.foldP(netSpring, netCard.implicitHeight + 8)) * 8;
        width: parent.width;
        opacity: panel.foldIn(netSpring, netCard.implicitHeight + 8);
        maxHeight: panel.foldRoom;
        title: panel.netList === "wifi" ? "Networks" : "Devices";
        action: panel.netList === "wifi"
          ? (Services.NetworkService.scanning ? "Scanning…" : "Rescan")
          : (Services.BluetoothService.scanning ? "Scanning…" : "Pair new");
        actionEnabled: panel.netList === "wifi" ? !Services.NetworkService.scanning : !Services.BluetoothService.scanning;
        onActionTapped: panel.netList === "wifi" ? Services.NetworkService.scan() : Services.BluetoothService.scan();

        WifiList { visible: panel.netList === "wifi"; Layout.fillWidth: true; }
        BluetoothList { visible: panel.netList === "bt"; Layout.fillWidth: true; }
      }
    }

    Item { width: 1; height: 8; }

    Row {
      width: parent.width;
      spacing: 8;

      SysTile {
        width: (parent.width - 8) / 2;
        glyph: String.fromCodePoint(0xf0176); // md-coffee
        title: "Keep awake";
        sub: Services.CaffeineService.active ? "Screen stays on" : "Off";
        on: Services.CaffeineService.active;
        onTapped: Services.CaffeineService.toggle();
        onIconTapped: Services.CaffeineService.toggle();
      }
      SysTile {
        width: (parent.width - 8) / 2;
        readonly property var pp: Services.PlatformProfileService;
        glyph: String.fromCodePoint(0xf140b); // md-lightning-bolt
        title: "Power";
        sub: (pp.autoMode ? "Auto · " : "") + (panel.modeNames[pp.profile] || pp.profile);
        on: pp.profile === "performance";
        chevron: "right";
        onTapped: panel.view = "power";
        onIconTapped: panel.view = "power";
      }
    }

    Item { width: 1; height: 12; }

    // --- sliders, with the audio devices folding open under volume ---
    RowLayout {
      width: parent.width;
      height: 40;
      spacing: 8;

      LevelSlider {
        Layout.fillWidth: true;
        enabled: Services.AudioService.available;
        glyph: Services.AudioService.iconGlyph;
        value: Services.AudioService.volume;
        dimmed: Services.AudioService.muted;
        valueLabel: Services.AudioService.muted ? "Muted" : Math.round(Services.AudioService.volume * 100) + "%";
        onMoved: (f) => Services.AudioService.setVolume(f);
        onIconTapped: Services.AudioService.toggleMute();
      }
      RoundButton {
        glyph: String.fromCodePoint(0xf0140); // md-chevron-down
        active: false;
        color: panel.audOpen || hovered ? CurrentTheme.chip : CurrentTheme.glass;
        turn: panel.foldP(audSpring, audCard.implicitHeight + 8);
        onClicked: panel.toggleView("audio");
      }
    }

    Item {
      width: parent.width;
      height: audSpring.value;
      clip: true;
      visible: height > 0.5;

      FoldCard {
        id: audCard;
        y: 8 - (1 - panel.foldP(audSpring, audCard.implicitHeight + 8)) * 8;
        width: parent.width;
        opacity: panel.foldIn(audSpring, audCard.implicitHeight + 8);
        maxHeight: panel.foldRoom;
        title: "Output";
        action: "Sound settings";
        onActionTapped: {
          panel.closeRequested();
          Quickshell.execDetached(["pavucontrol"]);
        }

        AudioList { Layout.fillWidth: true; }
      }
    }

    Item { width: 1; height: 8; }

    RowLayout {
      width: parent.width;
      height: 40;
      spacing: 8;

      LevelSlider {
        Layout.fillWidth: true;
        glyph: String.fromCodePoint(0xf05a8); // md-white-balance-sunny
        value: Services.BrightnessService.brightness;
        onMoved: (f) => Services.BrightnessService.setBrightness(f);
      }
      RoundButton {
        label: "A";
        active: Services.BrightnessService.autoMode;
        onClicked: {
          Services.BrightnessService.autoMode = !Services.BrightnessService.autoMode;
          if (Services.BrightnessService.autoMode) Services.BrightnessService.applyAutoCurve();
        }
      }
    }

    Item { width: 1; height: 8; }

    RowLayout {
      width: parent.width;
      height: 40;
      spacing: 8;

      // 0% = coolest, 100% = warmest (TemperatureService's fraction runs the
      // other way).
      LevelSlider {
        readonly property var ts: Services.TemperatureService;
        Layout.fillWidth: true;
        glyph: String.fromCodePoint(0xf050f); // md-thermometer
        temperature: true;
        value: (ts.maxTempK - ts.temperatureK) / (ts.maxTempK - ts.minTempK);
        onMoved: (f) => ts.setTemperature(1 - f);
      }
      RoundButton {
        label: "A";
        active: Services.TemperatureService.autoMode;
        onClicked: {
          Services.TemperatureService.autoMode = !Services.TemperatureService.autoMode;
          if (Services.TemperatureService.autoMode) Services.TemperatureService.applyAutoCurve();
        }
      }
    }
  }

  // ===== power page =====
  PowerPage {
    id: powerPage;
    x: Theme.defaultMargin;
    y: Theme.defaultMargin;
    width: panel.contentWidth;
    visible: pageSpring.value > 0.001 && panel.normalOp > 0;
    opacity: panel.pageP * panel.normalOp;
    scale: 0.97 + 0.03 * panel.pageP;
    transformOrigin: Item.Top;
    onBack: panel.view = "";
  }

  // ===== session confirm =====
  SessionConfirm {
    id: confirm;
    width: 430;
    shown: panel.confirming;
    visible: panel.confirmOp > 0;
    opacity: panel.confirmOp;
  }
}
