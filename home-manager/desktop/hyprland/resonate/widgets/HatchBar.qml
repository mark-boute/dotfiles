import QtQuick

import qs

// A rounded bar split into a solid (measured) part and a hatched (estimated)
// rest. fraction 1 is all solid, 0 all hatched.
Canvas {
  id: bar;

  property real fraction: 0;
  property real radius: height / 2;
  property real gap: 2;
  readonly property color ink: CurrentTheme.text;

  onFractionChanged: requestPaint();
  onInkChanged: requestPaint();
  onWidthChanged: requestPaint();

  onPaint: {
    var ctx = getContext("2d");
    ctx.reset();
    var w = width, h = height, r = Math.min(radius, h / 2);
    if (w <= 0 || h <= 0) return;
    ctx.beginPath();
    ctx.moveTo(r, 0); ctx.lineTo(w - r, 0); ctx.arcTo(w, 0, w, r, r);
    ctx.lineTo(w, h - r); ctx.arcTo(w, h, w - r, h, r);
    ctx.lineTo(r, h); ctx.arcTo(0, h, 0, h - r, r);
    ctx.lineTo(0, r); ctx.arcTo(0, 0, r, 0, r);
    ctx.closePath();
    ctx.clip();

    var f = Math.max(0, Math.min(1, fraction));
    var solid = f >= 1 ? w : f <= 0 ? 0 : Math.max(2, Math.min(w - gap - 2, w * f));
    ctx.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.85);
    ctx.fillRect(0, 0, solid, h);

    var x0 = solid > 0 && solid < w ? solid + gap : solid;
    if (x0 >= w) return;
    ctx.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.14);
    ctx.fillRect(x0, 0, w - x0, h);
    ctx.save();
    ctx.beginPath();
    ctx.rect(x0, 0, w - x0, h);
    ctx.clip();
    ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.32);
    ctx.lineWidth = h > 10 ? 2.8 : 1.4;
    var step = h > 10 ? 8 : 4;
    for (var x = x0 - h; x < w + h; x += step) {
      ctx.beginPath();
      ctx.moveTo(x, h);
      ctx.lineTo(x + h, 0);
      ctx.stroke();
    }
    ctx.restore();
  }
}
