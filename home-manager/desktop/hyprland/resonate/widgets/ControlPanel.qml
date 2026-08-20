import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

import qs
import qs.services as Services

// Opened by clicking the center widget: theme selector, a "now playing"
// banner when Spotify is active, and the full notification history with
// per-item dismiss / clear all.
Rectangle {
  id: panel;

  readonly property var flavors: ["latte", "frappe", "macchiato", "mocha"];
  readonly property int contentWidth: 300;

  // No border — the bar's islands went borderless for the same reason
  // (see Workspaces/Clock/PowerStatus.qml): an outline clashes with the
  // frosted-glass one-piece look this whole shell is going for now.
  // Square top corners for the same reason too — this panel opens
  // directly out of the clock island above it, so a fully rounded top
  // would visually disconnect from it the moment it's open.
  radius: 18;
  topLeftRadius: 0;
  topRightRadius: 0;
  color: CurrentTheme.surface;

  layer.enabled: true;
  layer.effect: MultiEffect {
    shadowEnabled: true;
    shadowColor: Theme.shadowColor;
    shadowBlur: Theme.shadowBlur;
    shadowVerticalOffset: Theme.shadowVerticalOffset;
  }

  // Smooths the concave seams where this panel's left/right edges meet
  // the connecting strip above (see NotchFillet.qml) — same treatment as
  // the clock island itself (Clock.qml): both sides, since this panel
  // stays centered on screen when open (see Bar.qml's CenterWidget/
  // panelLoader centering — a panel exactly as wide as its wrapper
  // renders with zero centering offset), just wider than the pill it
  // replaces.
  NotchFillet {
    id: leftFillet;
    x: -leftFillet.filletRadius;
    y: Theme.barConnectorHeight;
  }
  NotchFillet {
    id: rightFillet;
    mirrored: true;
    x: panel.width;
    y: Theme.barConnectorHeight;
  }

  implicitWidth: layout.implicitWidth + Theme.defaultMargin * 2;
  implicitHeight: Math.min(layout.implicitHeight, Theme.maxPanelContentHeight) + Theme.defaultMargin * 2;

  Behavior on implicitWidth  { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
  Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  // Flickable rather than a plain centered ColumnLayout — panel content
  // (theme swatches + a growing notification list) can end up taller than
  // the capped implicitHeight above, so this scrolls the overflow instead
  // of clipping it unreachably. Drag-to-pan is Flickable's own default
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

      // --- Now playing (Spotify only) ---
      RowLayout {
        Layout.preferredWidth: panel.contentWidth;
        Layout.alignment: Qt.AlignHCenter;
        visible: Services.MediaService.hasPlayer;
        spacing: Theme.defaultSpacing;
  
        ColumnLayout {
          Layout.fillWidth: true;
          spacing: 1;
  
          Text {
            Layout.fillWidth: true;
            text: Services.MediaService.title;
            color: CurrentTheme.text;
            font.pixelSize: 13;
            font.weight: Font.DemiBold;
            elide: Text.ElideRight;
          }
  
          Text {
            Layout.fillWidth: true;
            text: Services.MediaService.artist;
            color: CurrentTheme.subtext;
            font.pixelSize: 11;
            elide: Text.ElideRight;
          }
        }
  
        Text {
          text: "⏮";
          color: Services.MediaService.canGoPrevious ? CurrentTheme.text : CurrentTheme.subtext;
          font.pixelSize: 14;
          TapHandler { enabled: Services.MediaService.canGoPrevious; onTapped: Services.MediaService.previous(); }
        }
  
        Text {
          text: Services.MediaService.playing ? "⏸" : "▶";
          color: CurrentTheme.accent;
          font.pixelSize: 16;
          TapHandler { onTapped: Services.MediaService.togglePlaying(); }
        }
  
        Text {
          text: "⏭";
          color: Services.MediaService.canGoNext ? CurrentTheme.text : CurrentTheme.subtext;
          font.pixelSize: 14;
          TapHandler { enabled: Services.MediaService.canGoNext; onTapped: Services.MediaService.next(); }
        }
      }
  
      Rectangle {
        Layout.preferredWidth: panel.contentWidth;
        Layout.alignment: Qt.AlignHCenter;
        Layout.topMargin: Theme.defaultSpacing / 2;
        Layout.bottomMargin: Theme.defaultSpacing / 2;
        visible: Services.MediaService.hasPlayer;
        implicitHeight: 1;
        color: CurrentTheme.border;
      }
  
      // --- Theme ---
      Text {
        Layout.alignment: Qt.AlignHCenter;
        text: "Theme";
        color: CurrentTheme.subtext;
        font.pixelSize: 12;
        font.weight: Font.DemiBold;
      }
  
      RowLayout {
        Layout.alignment: Qt.AlignHCenter;
        spacing: Theme.defaultSpacing;
  
        Repeater {
          model: panel.flavors;
  
          Rectangle {
            id: swatch;
            required property string modelData;
            readonly property var flavorPalette: Theme.paletteFor(modelData);
            readonly property bool active: Theme.flavor === modelData;
  
            width: 58;
            height: 58;
            radius: 14;
            color: flavorPalette.base;
            border.width: active ? 2 : 1;
            border.color: active ? flavorPalette.mauve : CurrentTheme.border;
  
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on border.width { NumberAnimation { duration: 120 } }
  
            Row {
              anchors.centerIn: parent;
              spacing: 3;
  
              Repeater {
                model: [swatch.flavorPalette.rosewater, swatch.flavorPalette.mauve, swatch.flavorPalette.blue];
  
                Rectangle {
                  required property color modelData;
                  width: 8;
                  height: 8;
                  radius: 4;
                  color: modelData;
                }
              }
            }
  
            TapHandler {
              onTapped: Theme.flavor = swatch.modelData;
            }
          }
        }
      }
  
      Text {
        Layout.alignment: Qt.AlignHCenter;
        text: Theme.flavor.charAt(0).toUpperCase() + Theme.flavor.slice(1);
        color: CurrentTheme.text;
        font.pixelSize: 12;
      }
  
      Text {
        Layout.alignment: Qt.AlignHCenter;
        Layout.topMargin: Theme.defaultSpacing;
        text: "Accent";
        color: CurrentTheme.subtext;
        font.pixelSize: 12;
        font.weight: Font.DemiBold;
      }
  
      Flow {
        Layout.preferredWidth: panel.contentWidth;
        Layout.alignment: Qt.AlignHCenter;
        spacing: Theme.defaultSpacing;
  
        Repeater {
          model: Theme.accentChoices;
  
          Rectangle {
            id: accentSwatch;
            required property string modelData;
            readonly property bool active: Theme.accentName === modelData;
  
            width: 28;
            height: 28;
            radius: 14;
            color: Theme.palette[modelData];
            border.width: active ? 2 : 0;
            border.color: CurrentTheme.text;
  
            Behavior on border.width { NumberAnimation { duration: 120 } }
  
            TapHandler {
              onTapped: Theme.accentName = accentSwatch.modelData;
            }
          }
        }
      }
  
      // --- Notifications ---
      RowLayout {
        Layout.preferredWidth: panel.contentWidth;
        Layout.alignment: Qt.AlignHCenter;
        Layout.topMargin: Theme.defaultSpacing;
        visible: Services.NotificationService.trackedNotifications.values.length > 0;
  
        Text {
          text: "Notifications";
          color: CurrentTheme.subtext;
          font.pixelSize: 12;
          font.weight: Font.DemiBold;
          Layout.fillWidth: true;
        }
  
        Text {
          text: "Clear all";
          color: CurrentTheme.accent;
          font.pixelSize: 12;
          TapHandler { onTapped: Services.NotificationService.clearAll(); }
        }
      }
  
      ListView {
        id: notifList;
        Layout.preferredWidth: panel.contentWidth;
        Layout.alignment: Qt.AlignHCenter;
        Layout.preferredHeight: Math.min(contentHeight, 260);
        visible: Services.NotificationService.trackedNotifications.values.length > 0;
        clip: true;
        spacing: 6;
        model: Services.NotificationService.trackedNotifications;
  
        delegate: Rectangle {
          id: card;
          required property var modelData;
          width: notifList.width;
          height: body.implicitHeight + 20;
          radius: 10;
          color: CurrentTheme.background;
          border.width: 1;
          border.color: CurrentTheme.border;
  
          ColumnLayout {
            id: body;
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; }
            spacing: 2;
  
            RowLayout {
              Layout.fillWidth: true;
              spacing: 6;
  
              IconImage {
                implicitSize: 14;
                visible: source.toString() !== "";
                source: {
                  var n = card.modelData;
                  if (n.image) return n.image;
                  var ic = n.appIcon;
                  if (!ic) return "";
                  return (ic.startsWith("/") || ic.indexOf("://") !== -1) ? ic : Quickshell.iconPath(ic, true);
                }
              }
  
              Text {
                text: card.modelData.appName;
                color: CurrentTheme.subtext;
                font.pixelSize: 10;
                Layout.fillWidth: true;
              }
  
              Text {
                // A trash icon, not the clock spotlight's × — this removes
                // it from the list rather than just dismissing a toast.
                text: "🗑";
                color: CurrentTheme.subtext;
                font.pixelSize: 12;
                TapHandler { onTapped: card.modelData.dismiss(); }
              }
            }
  
            Text {
              Layout.fillWidth: true;
              text: card.modelData.summary;
              color: CurrentTheme.text;
              font.pixelSize: 12;
              font.weight: Font.DemiBold;
              elide: Text.ElideRight;
            }
  
            Text {
              Layout.fillWidth: true;
              visible: card.modelData.body !== "";
              text: card.modelData.body;
              color: CurrentTheme.subtext;
              font.pixelSize: 11;
              wrapMode: Text.WordWrap;
              maximumLineCount: 2;
              elide: Text.ElideRight;
            }
          }
        }
      }
    }
  }
}
