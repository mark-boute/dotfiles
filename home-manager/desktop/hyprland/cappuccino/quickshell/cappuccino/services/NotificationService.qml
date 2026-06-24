pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
  id: root;

  property alias trackedNotifications: server.trackedNotifications;

  property var _timers: ({})
  readonly property int dismissDelay: 10000;
  readonly property int fadeDuration: 5000;
  readonly property int fadeInDuration: 150;

  signal fadeOut(var notification)
  signal fadeIn(var notification)

  Component {
    id: timerComponent;
    Timer {
      required property var notification;
      property bool fading: false;
      interval: root.dismissDelay;
      repeat: false;
      onTriggered: {
        if (!fading) {
          fading = true;
          interval = root.fadeDuration;
          root.fadeOut(notification);
          restart();
        } else {
          var id = notification.id;
          notification.expire();
          root._clearTimer(id);
        }
      }
    }
  }

  function _clearTimer(notifId) {
    var t = root._timers[notifId];
    if (t) {
      t.stop();
      t.destroy();
      delete root._timers[notifId];
    }
  }

  // Restart the full countdown, cancelling any in-progress fade.
  function resetTimer(notification) {
    var t = root._timers[notification.id];
    if (!t) return;
    if (t.fading) {
      t.fading = false;
      root.fadeIn(notification);
    }
    t.interval = root.dismissDelay;
    t.restart();
  }

  // Pause the countdown, cancelling any in-progress fade.
  function stopTimer(notification) {
    var t = root._timers[notification.id];
    if (!t) return;
    t.stop();
    if (t.fading) {
      t.fading = false;
      t.interval = root.dismissDelay;
      root.fadeIn(notification);
    }
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

      // Don't auto-dismiss critical notifications
      if (n.urgency === NotificationUrgency.Critical) {
        return;
      }

      // If the app re-sent the same id, restart its existing timer instead of leaking a second one.
      if (root._timers[n.id]) {
        root._timers[n.id].restart();
        return;
      }

      var t = timerComponent.createObject(root, { notification: n });
      root._timers[n.id] = t;
      t.start();

      // dropped is on the Retainable attached property, not n directly.
      n.Retainable.dropped.connect(() => root._clearTimer(n.id));
    }

  }
}
