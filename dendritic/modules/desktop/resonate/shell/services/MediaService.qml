pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Specifically Spotify, not "whichever MPRIS player" — that's what was
// asked for, and it keeps the clock's hover state from randomly switching
// to controlling e.g. a browser tab's video.
Singleton {
  id: root;

  readonly property var activePlayer: {
    var players = Mpris.players.values;
    for (var i = 0; i < players.length; i++) {
      var p = players[i];
      var identity = (p.identity || "").toLowerCase();
      var dbusName = (p.dbusName || "").toLowerCase();
      if (identity.indexOf("spotify") !== -1 || dbusName.indexOf("spotify") !== -1) return p;
    }
    return null;
  }

  readonly property bool hasPlayer: activePlayer !== null;
  readonly property bool playing: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing;
  readonly property string title: activePlayer ? activePlayer.trackTitle : "";
  readonly property string artist: activePlayer ? activePlayer.trackArtist : "";
  readonly property string artUrl: activePlayer ? activePlayer.trackArtUrl : "";
  readonly property bool canGoNext: activePlayer !== null && activePlayer.canGoNext;
  readonly property bool canGoPrevious: activePlayer !== null && activePlayer.canGoPrevious;

  function togglePlaying() { if (activePlayer) activePlayer.togglePlaying(); }
  function next() { if (activePlayer && activePlayer.canGoNext) activePlayer.next(); }
  function previous() { if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous(); }
}
