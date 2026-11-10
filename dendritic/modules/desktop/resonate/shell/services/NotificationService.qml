pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Registers as the system's notification daemon (org.freedesktop.Notifications)
// — resonate doesn't have a separate toast overlay the way cappuccino does;
// the center widget itself is the toast (see widgets/Clock.qml), so this
// just needs to track the full list (for the control panel) and the single
// most recent one (for the clock's brief spotlight).
Singleton {
  id: root;

  property alias trackedNotifications: server.trackedNotifications;

  // Most recently arrived notification — the clock shows this briefly
  // before reverting to the plain time. Separate from each notification's
  // own lifetime in trackedNotifications, which persists until dismissed.
  property var latestNotification: null;
  readonly property int spotlightDuration: 6000;

  // Set by the clock's own hover state (see widgets/Clock.qml) — holds the
  // spotlight open indefinitely while you're actually looking at it, same
  // as cappuccino's NotificationOverlay pausing its dismiss timer on hover.
  property bool spotlightHeld: false;

  // Do-not-disturb: still recorded to history, just no spotlight/toast.
  property bool dnd: false;
  function toggleDnd() { root.dnd = !root.dnd; }

  // Persisted archive of everything that came through (newest first, capped).
  property var history: [];
  function clearHistory() { root.history = []; _saveState(); }

  property bool _stateReady: false;

  FileView {
    id: stateStore;
    path: (Quickshell.env("HOME") || "") + "/.config/resonate/notification-history.json";
    printErrors: false;
    onLoaded: {
      root.dnd = stateAdapter.dnd;
      root.history = stateAdapter.items || [];
      root._stateReady = true;
    }
    onLoadFailed: root._stateReady = true;
    JsonAdapter {
      id: stateAdapter;
      property bool dnd: false;
      property var items: [];
    }
  }
  function _saveState() {
    if (!root._stateReady) return;
    stateAdapter.dnd = root.dnd;
    stateAdapter.items = root.history;
    stateStore.writeAdapter();
  }
  onDndChanged: _saveState();
  Component.onCompleted: stateStore.reload();

  function _record(n) {
    var entry = {
      app: n.appName || "",
      summary: n.summary || "",
      body: n.body || "",
      icon: n.appIcon || "",
      image: String(n.image || ""),
      ts: Date.now(),
    };
    root.history = [entry].concat(root.history).slice(0, 120);
    root._saveState();
  }

  function dismiss(notification) {
    notification.dismiss();
  }

  // Invokes a notification's default action (or its only action, if it has
  // exactly one) and focuses the sending app — ported from cappuccino's
  // NotificationOverlay.qml click handling. With no action to invoke at
  // all, clicking just dismisses it instead of doing nothing.
  function invokeDefaultAction(notification) {
    var actions = notification.actions;
    var action = null;
    for (var i = 0; i < actions.length; i++) {
      if (actions[i].identifier === "default") { action = actions[i]; break; }
    }
    if (!action && actions.length === 1) action = actions[0];
    if (action) {
      focusApp(notification);
      action.invoke();
    } else {
      notification.dismiss();
    }
  }

  function clearAll() {
    var list = trackedNotifications.values.slice();
    for (var i = 0; i < list.length; i++) list[i].dismiss();
  }

  function focusApp(notification) {
    var id = notification.desktopEntry !== "" ? notification.desktopEntry : notification.appName;
    // Trailing .* because class: is a full regex match and the id is often a
    // prefix of the real class (e.g. "zen" -> "zen-beta" for a browser tab).
    if (id) Quickshell.execDetached(["hyprctl", "dispatch",
      "hl.dsp.focus({ window = \"class:(?i)" + id + ".*\" })"]);
  }

  Timer {
    id: spotlightTimer;
    interval: root.spotlightDuration;
    // Reactive rather than imperative start/stop: this way a hover that
    // begins or ends, or a new notification arriving mid-hover, all just
    // fall out of this one binding instead of needing to be coordinated
    // by hand. Going from held back to not-held restarts the full
    // duration, same as cappuccino's resetTimer.
    running: root.latestNotification !== null && !root.spotlightHeld;
    onTriggered: root.latestNotification = null;
  }

  NotificationServer {
    id: server;

    keepOnReload: true;
    actionsSupported: true;
    actionIconsSupported: true;
    bodySupported: true;
    bodyMarkupSupported: true;
    bodyHyperlinksSupported: true;
    bodyImagesSupported: true;
    imageSupported: true;

    persistenceSupported: false;

    onNotification: n => {
      n.tracked = true;
      root._record(n);
      if (!root.dnd)
        root.latestNotification = n;

      // dropped is on the Retainable attached property, not n directly.
      n.Retainable.dropped.connect(() => {
        if (root.latestNotification === n) root.latestNotification = null;
      });
    }
  }
}
