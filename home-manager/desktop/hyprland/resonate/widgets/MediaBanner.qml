import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Now-playing strip for the panel's home view — title/artist + transport
// controls. Collapses to nothing when Spotify isn't running (visible bound by
// the caller, but it also self-hides).
RowLayout {
  id: root;
  visible: Services.MediaService.hasPlayer;
  spacing: Theme.defaultSpacing;

  ColumnLayout {
    Layout.fillWidth: true;
    spacing: 1;
    Text {
      Layout.fillWidth: true;
      text: Services.MediaService.title;
      color: CurrentTheme.text;
      font.pixelSize: 13; font.weight: Font.DemiBold;
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
    text: String.fromCodePoint(0xf048); // prev
    font.family: Theme.iconFontFamily;
    color: Services.MediaService.canGoPrevious ? CurrentTheme.text : CurrentTheme.subtext;
    font.pixelSize: 13;
    TapHandler { enabled: Services.MediaService.canGoPrevious; onTapped: Services.MediaService.previous(); }
  }
  Text {
    text: Services.MediaService.playing ? String.fromCodePoint(0xf04c) : String.fromCodePoint(0xf04b);
    font.family: Theme.iconFontFamily;
    color: CurrentTheme.text;
    font.pixelSize: 15;
    TapHandler { onTapped: Services.MediaService.togglePlaying(); }
  }
  Text {
    text: String.fromCodePoint(0xf051); // next
    font.family: Theme.iconFontFamily;
    color: Services.MediaService.canGoNext ? CurrentTheme.text : CurrentTheme.subtext;
    font.pixelSize: 13;
    TapHandler { enabled: Services.MediaService.canGoNext; onTapped: Services.MediaService.next(); }
  }
}
