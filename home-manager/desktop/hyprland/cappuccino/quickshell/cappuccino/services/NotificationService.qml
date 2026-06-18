pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
  id: root;

  // Map from notifId → Notification object (for close() calls)
  property var _notifMap: ({})

  ListModel {
    id: toastModel;
  }

  // Exposed to the overlay; index 0 is always the newest notification.
  property alias toasts: toastModel;

  // Set by any overlay when the cursor is over a toast; -1 when none hovered.
  // All overlay delegates on all screens react to this so a hover on one screen
  // stops the timers on every screen's delegate for the same notification.
  property int hoveredNotifId: -1;

  // Idempotent — safe to call from multiple overlay timers for the same ID.
  function dismiss(notifId) {
    for (var i = 0; i < toastModel.count; i++) {
      if (toastModel.get(i).notifId === notifId) {
        var notif = root._notifMap[notifId];
        delete root._notifMap[notifId];
        toastModel.remove(i);
        if (notif && typeof notif.close === "function") notif.close();
        return;
      }
    }
  }

  NotificationServer {
    id: server;
    keepOnReload: true;

    onNotification: notif => {
      // Replace in-place if the app re-sent the same notification ID.
      for (var i = 0; i < toastModel.count; i++) {
        if (toastModel.get(i).notifId === notif.id) {
          toastModel.set(i, {
            notifId: notif.id,
            summary: notif.summary || "",
            body:    notif.body    || "",
            appName: notif.appName || "",
            urgency: notif.urgency,
            timeout: notif.expireTimeout > 0 ? notif.expireTimeout : 5000
          });
          root._notifMap[notif.id] = notif;
          return;
        }
      }
      root._notifMap[notif.id] = notif;
      toastModel.insert(0, {
        notifId: notif.id,
        summary: notif.summary || "",
        body:    notif.body    || "",
        appName: notif.appName || "",
        urgency: notif.urgency,
        timeout: notif.expireTimeout > 0 ? notif.expireTimeout : 5000
      });
    }
  }
}
