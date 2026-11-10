pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Thin wrapper around Pipewire's default sink, shared by the power bar
// widget (mute button) and the power panel (mute button + volume slider) —
// each needs the sink's properties live-tracked independently, so this
// centralizes the PwObjectTracker instead of duplicating it per call site.
Singleton {
  id: root;

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink].concat(root.sinks).concat(root.sources).concat(root.streams)
      .filter(function (n) { return n; });
  }

  // Output devices and per-app playback streams — for the panel's output
  // switcher + per-app volume rows.
  readonly property var sinks: Pipewire.nodes.values.filter(function (n) {
    return n && n.isSink && !n.isStream && n.audio;
  });
  readonly property var streams: Pipewire.nodes.values.filter(function (n) {
    return n && n.isStream && n.audio
      && ((n.properties || {})["media.class"] || "") === "Stream/Output/Audio";
  });

  readonly property var sources: Pipewire.nodes.values.filter(function (n) {
    return n && !n.isSink && !n.isStream && n.audio;
  });

  function setSink(node) { if (node) Pipewire.preferredDefaultAudioSink = node; }
  function setSource(node) { if (node) Pipewire.preferredDefaultAudioSource = node; }
  function isDefaultSource(node) { return !!node && !!Pipewire.defaultAudioSource && node.id === Pipewire.defaultAudioSource.id; }
  function isDefaultSink(node) { return !!node && !!sink && node.id === sink.id; }
  function nodeLabel(n) {
    if (!n) return "";
    return n.description || n.nickname || (n.properties || {})["application.name"]
      || (n.properties || {})["media.name"] || n.name || "Audio";
  }
  function setNodeVolume(n, v) {
    if (n && n.audio) n.audio.volume = Math.max(0, Math.min(1, v));
  }
  function toggleNodeMute(n) { if (n && n.audio) n.audio.muted = !n.audio.muted; }

  readonly property var sink: Pipewire.defaultAudioSink;
  readonly property var audio: sink ? sink.audio : null;
  readonly property bool available: audio !== null;
  readonly property bool muted: audio ? audio.muted : false;
  readonly property real volume: audio ? audio.volume : 0;
  property bool showOsd: false;

  // Nerd Font glyphs (md-volume_mute / md-volume_high) — supplementary
  // plane codepoints, hence fromCodePoint rather than a \u escape.
  readonly property string iconGlyph: String.fromCodePoint(muted ? 0xf075f : 0xf057e);

  function toggleMute() {
    if (audio) audio.muted = !audio.muted;
  }

  function setVolume(v) {
    if (audio) audio.volume = Math.max(0, Math.min(1, v));
  }

  // Unlike brightness/temperature (no live readback — hence their IPC-
  // per-keypress plumbing), volume already has one: `volume`/`muted`
  // above are bound straight to Pipewire's own live state. So the
  // keybinds (hypr/keybinds.lua) just call pamixer directly, same as
  // before this feature existed, and the OSD flashes reactively off
  // whatever Pipewire reports changing — from a keybind, pavucontrol,
  // anything. This sidesteps a real problem the earlier IPC-per-keypress
  // version had: Hyprland's native key-repeat fires every ~40ms, faster
  // than a `quickshell ipc call` round trip completes, so holding the
  // key built up a backlog of in-flight calls that kept landing (and
  // restarting the OSD's hide timer) well after release — brightness/
  // temperature never built up that backlog in practice (brightnessctl
  // itself is fast), so only volume's revert felt sluggish.
  //
  // `ready` guards against flashing once at startup: `audio` attaches
  // asynchronously as Pipewire enumerates devices, and that first
  // attach itself fires volumeChanged/mutedChanged the same as a real
  // change would.
  property bool ready: false;
  Timer { interval: 500; running: true; onTriggered: root.ready = true; }

  function flashOsd() {
    root.showOsd = true;
    osdTimer.restart();
  }
  onVolumeChanged: if (root.ready) root.flashOsd();
  onMutedChanged: if (root.ready) root.flashOsd();

  Timer {
    id: osdTimer;
    interval: 2000;
    onTriggered: root.showOsd = false;
  }
}
