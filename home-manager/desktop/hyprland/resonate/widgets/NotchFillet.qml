import QtQuick
import QtQuick.Shapes

import qs

// A small quarter-disk "fillet" that smooths the concave right-angle
// junction where an island's edge meets the bar's connecting strip
// (Bar.qml), so the island reads as curving smoothly out of the strip
// (Dynamic-Island style) instead of meeting it at a sharp step. Default
// shape is for an island's LEFT edge (the strip continues further left);
// set `mirrored: true` for an island's right edge instead — a horizontal
// flip transform (on this whole Item, so the bridge below mirrors right
// along with the curve) rather than a second hand-derived path, so the
// two sides can't drift out of sync with each other.
Item {
  id: fillet;

  property bool mirrored: false;
  property real filletRadius: Theme.notchFilletRadius;

  width: filletRadius;
  height: filletRadius;

  transform: Scale { xScale: fillet.mirrored ? -1 : 1; origin.x: fillet.width / 2; }

  Shape {
    anchors.fill: parent;
    preferredRendererType: Shape.CurveRenderer;

    ShapePath {
      fillColor: CurrentTheme.surface;
      strokeWidth: -1;

      // (0,0): strip's bottom edge, filletRadius before the island.
      // (r,0): the junction corner itself, where strip meets island.
      // (r,r): tangent point on the island's own straight vertical edge.
      // Arc back to (0,0) bulges toward the strip, carving the concave curve.
      startX: 0; startY: 0;
      PathLine { x: fillet.filletRadius; y: 0 }
      PathLine { x: fillet.filletRadius; y: fillet.filletRadius }
      PathArc {
        x: 0; y: 0;
        radiusX: fillet.filletRadius; radiusY: fillet.filletRadius;
        direction: PathArc.Counterclockwise;
      }
    }
  }

}
