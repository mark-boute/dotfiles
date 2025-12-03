pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root;
  readonly property string time: Qt.formatTime(clock.date, "hh:mm");
  readonly property string datetime: Qt.formatDateTime(clock.date, "hh:mm | dddd, dd MMM");

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}