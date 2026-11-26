import QtQuick

import qs

// An arrow pointing where the wind blows to. `dir` is the meteorological
// direction it comes FROM (degrees, 0 = north), hence the +180.
Text {
  property real dir: 0;
  property int size: 10;

  text: "↑";
  font.pixelSize: size;
  font.weight: Font.DemiBold;
  color: CurrentTheme.subtext;
  rotation: (dir + 180) % 360;
}
