import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Opened from the drawer's Lights tile (see AppDrawer.qml), only reachable
// while Services.LightsService.reachable — see that file for why "a bulb
// answered on the LAN" is the whole presence check, no separate network
// detection. One card per bulb: power (PillButton), brightness (SliderPill,
// same widget/contract PowerPanel.qml uses for screen brightness), and a
// ColorWheel revealed by tapping "Color" — collapsed by default so a
// multi-bulb list doesn't turn into a wall of pickers.
ColumnLayout {
  id: root;
  spacing: Theme.defaultSpacing;

  readonly property int appWidth: 380;

  // Which device's ColorWheel is expanded, by id (not by delegate — the
  // Repeater below rebuilds on every poll since `devices` is a fresh array
  // each time, so anything per-delegate wouldn't survive a poll landing
  // while a card is expanded).
  property string expandedId: "";

  // Drives LightsService's poll cadence (5s while open vs 25s in the
  // background) — same completion-hook idiom ChecklistPanel.qml uses for
  // reload().
  Component.onCompleted: Services.LightsService.appActive = true;
  Component.onDestruction: Services.LightsService.appActive = false;

  Text {
    Layout.topMargin: Theme.defaultSpacing;
    Layout.alignment: Qt.AlignHCenter;
    text: "Lights";
    color: CurrentTheme.subtext;
    font.pixelSize: 12; font.weight: Font.DemiBold;
  }

  Text {
    Layout.alignment: Qt.AlignHCenter;
    Layout.preferredWidth: root.appWidth - Theme.defaultMargin * 2;
    visible: Services.LightsService.error !== "";
    text: Services.LightsService.error;
    color: CurrentTheme.danger;
    font.pixelSize: 11;
    horizontalAlignment: Text.AlignHCenter;
    wrapMode: Text.WordWrap;
  }

  Text {
    Layout.alignment: Qt.AlignHCenter;
    visible: Services.LightsService.devices.length === 0 && Services.LightsService.error === "";
    text: Services.LightsService.loading ? "Looking for lights…" : "No lights found.";
    color: CurrentTheme.subtext;
    font.pixelSize: 11;
  }

  Repeater {
    model: Services.LightsService.devices;

    ColumnLayout {
      id: row;
      required property int index;

      // Read the *live* array element rather than the Repeater's `modelData`:
      // LightsService applies optimistic edits by mutating the element in
      // place, and those never reach `modelData` (a detached copy), so a
      // slider bound through `modelData` freezes until the next poll swaps the
      // whole array. Re-reading `devices[index]` on every statusRevision tick
      // (an optimistic edit *or* a poll landing) is what keeps the handle
      // glued to the drag. Same statusRevision-gated-binding idiom as
      // AppDrawer.qml.
      readonly property var dev: {
        Services.LightsService.statusRevision;
        return Services.LightsService.devices[row.index] || ({});
      }
      readonly property bool expanded: root.expandedId === (dev.id || "");

      // The optimistically-mutated scalars: read statusRevision first so the
      // binding is guaranteed to re-run on an in-place edit (a fresh `dev`
      // object ref is not — QML may not re-emit for an unchanged reference),
      // then pull the value straight off the live element.
      readonly property bool devOn: { Services.LightsService.statusRevision; return (Services.LightsService.devices[row.index] || {}).on || false; }
      readonly property real devBrightness: { Services.LightsService.statusRevision; return (Services.LightsService.devices[row.index] || {}).brightness || 0; }
      readonly property real devTemperature: { Services.LightsService.statusRevision; return (Services.LightsService.devices[row.index] || {}).temperature || 0; }
      readonly property var devRgb: { Services.LightsService.statusRevision; return (Services.LightsService.devices[row.index] || {}).rgb || [255, 255, 255]; }

      Layout.preferredWidth: root.appWidth;
      spacing: 0;

      Rectangle {
        Layout.preferredWidth: root.appWidth;
        implicitHeight: cardCol.implicitHeight + Theme.defaultSpacing * 2;
        radius: 14;
        color: CurrentTheme.backgroundGlass;
        border.width: 1;
        border.color: CurrentTheme.border;
        clip: true;

        Behavior on implicitHeight { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        ColumnLayout {
          id: cardCol;
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.defaultSpacing; }
          spacing: Theme.defaultSpacing;

          RowLayout {
            Layout.fillWidth: true;
            spacing: Theme.defaultSpacing;

            Rectangle {
              width: 8; height: 8; radius: 4;
              color: row.dev.reachable ? CurrentTheme.success : CurrentTheme.danger;
            }

            Text {
              Layout.fillWidth: true;
              text: row.dev.name;
              color: CurrentTheme.text;
              font.pixelSize: 13; font.weight: Font.DemiBold;
              elide: Text.ElideRight;
            }

            PillButton {
              label: row.devOn ? "On" : "Off";
              accent: row.devOn;
              enabled: row.dev.reachable;
              onClicked: Services.LightsService.setPower(row.dev.id, !row.devOn);
            }
          }

          SliderPill {
            id: brightnessSlider;
            Layout.fillWidth: true;
            visible: (row.dev.caps || []).indexOf("brightness") >= 0;
            enabled: row.dev.reachable;
            value: row.devBrightness;
            valueLabel: Math.round(row.devBrightness * 100) + "%";
            onMoved: (fraction) => Services.LightsService.setBrightness(row.dev.id, fraction);
            onDraggingChanged: Services.LightsService.dragActive = dragging;
          }

          // White warmth — the primary control for these bulbs. Slider reads
          // 0% = coolest, 100% = warmest; devTemperature is the opposite
          // (raw DP: 0 = warmest), hence the 1 - x on the way in and out.
          SliderPill {
            id: warmthSlider;
            Layout.fillWidth: true;
            visible: (row.dev.caps || []).indexOf("temperature") >= 0;
            enabled: row.dev.reachable;
            temperature: true;
            value: 1 - row.devTemperature;
            valueLabel: Math.round((1 - row.devTemperature) * 100) + "%";
            onMoved: (fraction) => Services.LightsService.setTemperature(row.dev.id, 1 - fraction);
            onDraggingChanged: Services.LightsService.dragActive = dragging;
          }

          // --- color row / expand toggle ---
          Item {
            id: colorToggle;
            Layout.fillWidth: true;
            visible: (row.dev.caps || []).indexOf("color") >= 0;
            implicitHeight: colorRow.implicitHeight + Theme.defaultSpacing;

            Rectangle {
              anchors.fill: parent;
              anchors.leftMargin: -Theme.defaultSpacing / 2;
              anchors.rightMargin: -Theme.defaultSpacing / 2;
              radius: 8;
              color: colorHover.hovered && row.dev.reachable ? CurrentTheme.surfaceHover : "transparent";
              Behavior on color { ColorAnimation { duration: 100 } }
            }

            RowLayout {
              id: colorRow;
              anchors.verticalCenter: parent.verticalCenter;
              width: parent.width;
              spacing: Theme.defaultSpacing;

              Rectangle {
                width: 16; height: 16; radius: 8;
                border.width: 1;
                border.color: CurrentTheme.border;
                color: Qt.rgba(row.devRgb[0] / 255, row.devRgb[1] / 255, row.devRgb[2] / 255, 1);
              }
              Text {
                Layout.fillWidth: true;
                text: "Color";
                color: colorHover.hovered && row.dev.reachable ? CurrentTheme.text : CurrentTheme.subtext;
                font.pixelSize: 11;
              }
              Text {
                text: row.expanded ? String.fromCodePoint(0xf0143) : String.fromCodePoint(0xf0140); // chevron up/down
                font.family: Theme.iconFontFamily;
                font.pixelSize: Theme.iconSize;
                color: colorHover.hovered && row.dev.reachable ? CurrentTheme.text : CurrentTheme.subtext;
              }
            }

            HoverHandler {
              id: colorHover;
              enabled: row.dev.reachable;
              cursorShape: Qt.PointingHandCursor;
            }
            TapHandler {
              enabled: row.dev.reachable;
              onTapped: root.expandedId = row.expanded ? "" : row.dev.id;
            }
          }

          ColorWheel {
            id: wheel;
            Layout.alignment: Qt.AlignHCenter;
            Layout.topMargin: Theme.defaultSpacing / 2;
            visible: row.expanded;

            // Seeded from the polled color whenever this card's wheel becomes
            // visible — plain property assignment, not `changed`-emitting, so
            // this can never loop back into a spurious write (see
            // ColorWheel.qml). Re-seeding only on expand (not on every poll)
            // means a live color update from elsewhere (e.g. voice control)
            // won't yank the wheel while it happens to be open; reopening it
            // picks up the latest value.
            onVisibleChanged: if (visible) {
              var hsv = Services.LightsService.rgbToHsv(row.devRgb[0], row.devRgb[1], row.devRgb[2]);
              hue = hsv.h; sat = hsv.s; val = hsv.v;
            }

            onChanged: (h, s, v) => Services.LightsService.setColor(row.dev.id, h, s, v);
            onDragStarted: Services.LightsService.dragActive = true;
            onDragEnded: Services.LightsService.dragActive = false;
          }
        }
      }
    }
  }
}
