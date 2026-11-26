import QtQuick

// A critically damped spring (no overshoot) easing `value` toward `to`.
// Growing and shrinking each get their own period and start delay, so a pill
// can widen before it deepens and flatten before it narrows (see Slot.qml).
// While `live` is false, `value` just follows `to`.
Item {
  id: s;

  property real to: 0;
  property real value: 0;
  property bool live: true;
  property real growPeriod: 0.55;
  property real growDelay: 0;
  property real shrinkPeriod: 0.40;
  property real shrinkDelay: 0;
  property real epsilon: 0.25;
  readonly property bool moving: anim.running;

  property real _vel: 0;
  property real _goal: 0;
  property real _k: 0;
  property real _c: 0;
  property real _wait: 0;

  function snap() {
    anim.stop();
    s._vel = 0; s._wait = 0; s._goal = s.to;
    s.value = s.to;
  }

  function _retarget() {
    if (!s.live) { s.snap(); return; }
    if (s.to === s._goal && s._wait === 0) return;
    var grow = s.to > s.value;
    var T = grow ? s.growPeriod : s.shrinkPeriod;
    s._k = Math.pow(2 * Math.PI / T, 2);
    s._c = 4 * Math.PI / T;
    s._wait = grow ? s.growDelay : s.shrinkDelay;
    if (s._wait <= 0) s._goal = s.to;
    anim.start();
  }

  // Deferred a tick so a `live` flag that flips alongside `to` is settled first.
  onToChanged: Qt.callLater(s._retarget);
  Component.onCompleted: snap();

  FrameAnimation {
    id: anim;
    onTriggered: {
      var dt = Math.min(frameTime, 0.05);
      if (s._wait > 0) {
        s._wait -= dt;
        if (s._wait <= 0) { s._wait = 0; s._goal = s.to; }
      }
      var n = Math.max(1, Math.ceil(dt / 0.004)), h = dt / n;
      var v = s.value, vel = s._vel;
      for (var i = 0; i < n; i++) {
        vel += (-s._k * (v - s._goal) - s._c * vel) * h;
        v += vel * h;
      }
      if (s._wait === 0 && Math.abs(v - s._goal) < s.epsilon && Math.abs(vel) < s.epsilon * 8) {
        v = s._goal; vel = 0;
        anim.stop();
      }
      s._vel = vel;
      s.value = v;
    }
  }
}
