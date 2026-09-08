import QtQuick

import qs
import qs.services as Services

// The apps drawer: a full-width now-playing card (when Spotify is running) on
// top of a grid of status tiles — Theme spans 2 columns, Checklist 1, and
// Lights 1 more when Services.LightsService.reachable (hidden the rest of the
// time — that's the "only show it when I'm home" behavior; see
// LightsService.qml, which treats "any bulb answering on the LAN" as the
// whole presence check). Each tile previews live status and, tapped, opens
// that app full-screen via the open(appId) signal.
Column {
  id: drawer;

  property int columns: Services.LightsService.reachable ? 4 : 3;
  property int gap: Theme.defaultSpacing;
  signal open(string appId);

  spacing: gap;

  readonly property real unit: (width - gap * (columns - 1)) / columns;
  function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""; }

  // --- Now playing (full width) ---
  MediaCard {
    width: parent.width;
    height: 58;
    visible: Services.MediaService.hasPlayer;
  }

  // --- tile row ---
  Row {
    width: parent.width;
    spacing: drawer.gap;

    // Theme (2 units)
    DrawerTile {
      width: drawer.unit * 2 + drawer.gap;
      height: drawer.unit;
      onActivated: drawer.open("theme");

      Row {
        anchors.verticalCenter: parent.verticalCenter;
        spacing: 12;

        Column {
          anchors.verticalCenter: parent.verticalCenter;
          spacing: 4;
          Repeater {
            model: [Theme.palette.rosewater, Theme.palette.yellow, Theme.palette.green,
                    Theme.palette.blue, Theme.palette.mauve];
            Rectangle {
              required property color modelData;
              width: 26; height: 5; radius: 2.5;
              color: modelData;
            }
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter;
          spacing: 2;
          Text {
            text: "Theme";
            color: CurrentTheme.subtext;
            font.pixelSize: 10; font.weight: Font.DemiBold;
          }
          Row {
            spacing: 4;
            Text {
              text: drawer.cap(Theme.flavor);
              color: CurrentTheme.text;
              font.pixelSize: 14; font.weight: Font.DemiBold;
            }
            Text {
              visible: Services.ThemeService.autoMode;
              anchors.verticalCenter: parent.verticalCenter;
              text: String.fromCodePoint(0xf0599); // md-weather-sunset
              font.family: Theme.iconFontFamily;
              font.pixelSize: 12;
              color: CurrentTheme.subtext;
            }
          }
          Row {
            spacing: 5;
            Rectangle {
              width: 10; height: 10; radius: 5;
              anchors.verticalCenter: parent.verticalCenter;
              color: CurrentTheme.accent;
            }
            Text {
              text: drawer.cap(Theme.accentName);
              color: CurrentTheme.subtext;
              font.pixelSize: 11;
              anchors.verticalCenter: parent.verticalCenter;
            }
          }
        }
      }
    }

    // Checklist (1 unit)
    DrawerTile {
      id: checkTile;
      width: drawer.unit;
      height: drawer.unit;
      onActivated: drawer.open("checklist");

      readonly property var counts: {
        var _s = Services.ChecklistService.revision + Services.ChecklistService.checkRev;
        return Services.ChecklistService.rootCounts();
      }

      Column {
        anchors.centerIn: parent;
        spacing: 6;

        Text {
          anchors.horizontalCenter: parent.horizontalCenter;
          text: String.fromCodePoint(0xf0ae); // nf-fa-tasks
          font.family: Theme.iconFontFamily;
          font.pixelSize: 24;
          color: CurrentTheme.accent;
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter;
          text: checkTile.counts.total > 0
            ? (checkTile.counts.done + " / " + checkTile.counts.total)
            : "Checklist";
          color: CurrentTheme.subtext;
          font.pixelSize: 10; font.weight: Font.DemiBold;
        }
      }
    }

    // Lights (1 unit) — only ever present in the grid while reachable, per
    // `columns` above; `visible: false` also makes Row skip it entirely
    // rather than leaving a gap.
    DrawerTile {
      id: lightsTile;
      width: drawer.unit;
      height: drawer.unit;
      visible: Services.LightsService.reachable;
      onActivated: drawer.open("lights");

      readonly property var devs: {
        var _s = Services.LightsService.statusRevision;
        return Services.LightsService.devices;
      }
      readonly property int onCount: devs.filter((d) => d.on).length;

      Column {
        anchors.centerIn: parent;
        spacing: 6;

        Text {
          anchors.horizontalCenter: parent.horizontalCenter;
          text: String.fromCodePoint(0xf0335); // md-lightbulb
          font.family: Theme.iconFontFamily;
          font.pixelSize: 24;
          color: lightsTile.onCount > 0 ? CurrentTheme.accent : CurrentTheme.subtext;
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter;
          text: lightsTile.devs.length > 0
            ? (lightsTile.onCount + " / " + lightsTile.devs.length)
            : "Lights";
          color: CurrentTheme.subtext;
          font.pixelSize: 10; font.weight: Font.DemiBold;
        }
      }
    }
  }
}
