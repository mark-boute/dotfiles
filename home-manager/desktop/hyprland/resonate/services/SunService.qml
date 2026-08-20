pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Location via IP geolocation (ip-api.com, no key required) fetched once
// at startup and refreshed daily — a laptop can travel, but location
// doesn't change minute to minute, so there's no reason to poll more
// often than that. Falls back to a fixed default if the request ever
// fails (no network, API down, etc.) rather than leaving the curve
// broken. Sunrise/sunset themselves are computed locally afterwards (the
// standard Sunrise/Sunset Algorithm from the Astronomical Almanac), not
// fetched from a second API, so the actual curve keeps working offline
// once a location is known.
Singleton {
  id: root;

  property real latitude: 52.0;
  property real longitude: 5.0;

  Process {
    id: geoProc;
    command: ["curl", "-s", "--max-time", "5", "http://ip-api.com/json"];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        try {
          var data = JSON.parse(t || "{}");
          if (data.status === "success" && typeof data.lat === "number") {
            root.latitude = data.lat;
            root.longitude = data.lon;
          }
        } catch (e) {
          // Keep the fallback default — better than a broken curve.
        }
      }
    }
  }

  Component.onCompleted: geoProc.running = true;

  Timer {
    interval: 24 * 60 * 60 * 1000;
    repeat: true;
    running: true;
    onTriggered: geoProc.running = true;
  }

  // Today's sunrise/sunset as fractional local hours (7.5 = 07:30), or
  // null components for the (here, irrelevant-in-practice) polar day/
  // night edge case where the sun doesn't rise or set at all.
  function sunTimesForToday() {
    var date = new Date();
    var zenith = 90.83; // official sunrise/sunset, includes atmospheric refraction
    var rad = Math.PI / 180;

    function dayOfYear(d) {
      var start = new Date(d.getFullYear(), 0, 1);
      return Math.floor((d - start) / 86400000) + 1;
    }

    function compute(isSunrise) {
      var N = dayOfYear(date);
      var lngHour = root.longitude / 15;
      var t = N + ((isSunrise ? 6 : 18) - lngHour) / 24;
      var M = (0.9856 * t) - 3.289;
      var L = M + (1.916 * Math.sin(M * rad)) + (0.020 * Math.sin(2 * M * rad)) + 282.634;
      L = (L % 360 + 360) % 360;
      var RA = (1 / rad) * Math.atan(0.91764 * Math.tan(L * rad));
      RA = (RA % 360 + 360) % 360;
      var Lquadrant = Math.floor(L / 90) * 90;
      var RAquadrant = Math.floor(RA / 90) * 90;
      RA = (RA + (Lquadrant - RAquadrant)) / 15;
      var sinDec = 0.39782 * Math.sin(L * rad);
      var cosDec = Math.cos(Math.asin(sinDec));
      var cosH = (Math.cos(zenith * rad) - (sinDec * Math.sin(root.latitude * rad)))
        / (cosDec * Math.cos(root.latitude * rad));
      if (cosH > 1 || cosH < -1) return null;
      var H = isSunrise ? (360 - (1 / rad) * Math.acos(cosH)) : ((1 / rad) * Math.acos(cosH));
      H = H / 15;
      var T = H + RA - (0.06571 * t) - 6.622;
      return (T - lngHour + 24) % 24; // fractional UTC hour
    }

    function utcHourToLocalFraction(utcHour) {
      if (utcHour === null) return null;
      var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0));
      d.setUTCMinutes(utcHour * 60);
      return d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600;
    }

    return {
      sunrise: utcHourToLocalFraction(compute(true)),
      sunset: utcHourToLocalFraction(compute(false)),
    };
  }

  // Smooth day/night curve shared by brightness and temperature auto
  // modes: nightValue outside a `transitionHours`-wide window centered
  // on each of sunrise/sunset, dayValue in between, eased (not a hard
  // cut) across each transition so it doesn't visibly snap.
  function curveValue(nightValue, dayValue, transitionHours) {
    var times = sunTimesForToday();
    if (times.sunrise === null || times.sunset === null) return dayValue;
    var now = new Date();
    var h = now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600;

    function ease(x) { return (1 - Math.cos(x * Math.PI)) / 2; }

    var half = transitionHours / 2;
    if (h > times.sunrise - half && h < times.sunrise + half) {
      var fr = (h - (times.sunrise - half)) / transitionHours;
      return nightValue + (dayValue - nightValue) * ease(fr);
    }
    if (h > times.sunset - half && h < times.sunset + half) {
      var fs = (h - (times.sunset - half)) / transitionHours;
      return dayValue + (nightValue - dayValue) * ease(fs);
    }
    if (h > times.sunrise + half && h < times.sunset - half) return dayValue;
    return nightValue;
  }
}
