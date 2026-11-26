import QtQuick
import Quickshell.Widgets

import qs
import qs.services as Services

// Full-width now-playing card for the drawer. When Spotify exposes album art
// it becomes the card's background (cropped, behind a scrim tinted toward the
// theme base so the banner text stays readable); otherwise it's a plain tile.
ClippingRectangle {
  id: card;

  radius: 16;
  color: CurrentTheme.backgroundGlass;
  border.width: 1;
  border.color: CurrentTheme.border;

  readonly property string art: Services.MediaService.artUrl;
  readonly property bool hasArt: art !== "" && albumArt.status === Image.Ready;

  Image {
    id: albumArt;
    anchors.fill: parent;
    source: card.art;
    fillMode: Image.PreserveAspectCrop;
    cache: true;
    asynchronous: true;
    visible: card.hasArt;
  }

  Rectangle {
    anchors.fill: parent;
    visible: card.hasArt;
    color: Qt.rgba(CurrentTheme.background.r, CurrentTheme.background.g,
                   CurrentTheme.background.b, 0.55);
  }

  // Match the panel's own margin so the controls don't crowd the right edge.
  MediaBanner {
    anchors.fill: parent;
    anchors.leftMargin: Theme.defaultMargin;
    anchors.rightMargin: Theme.defaultMargin;
  }
}
