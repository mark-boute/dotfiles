pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root;
  readonly property string time: Qt.formatTime(clock.date, "hh:mm");
  readonly property string weekday: Qt.formatDate(clock.date, "dddd");
  readonly property string date: Qt.formatDate(clock.date, "d MMMM yyyy");

  SystemClock {
    id: clock;
    precision: SystemClock.Minutes;
  }
}
