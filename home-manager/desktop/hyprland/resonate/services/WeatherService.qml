pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Weather from open-meteo (no API key). Location comes from SunService's IP
// geolocation. Current conditions drive the small clock-pill indicator; the
// hourly + 3-day arrays feed the panel's home-view weather card.
Singleton {
  id: root;

  property real temp: NaN;
  property int code: -1;
  property bool isDay: true;
  property var hourly: [];   // [{ hour, temp, glyph, wind, windDir }]  next ~12h
  property var daily: [];    // [{ label, min, max, glyph, wind, gust, windDir }]  next 3 days
  // km/h; direction is where the wind comes FROM, in degrees (meteorological).
  property real wind: NaN;
  property real gust: NaN;
  property real windDir: 0;

  readonly property bool ready: !isNaN(temp);
  readonly property string glyph: _glyph(code, isDay);
  readonly property string desc: _desc(code);
  readonly property string tempText: ready ? Math.round(temp) + "°" : "";

  function _glyph(c, day) {
    if (c === 0) return String.fromCodePoint(day ? 0xf0599 : 0xf0594);
    if (c === 1 || c === 2) return String.fromCodePoint(day ? 0xf0595 : 0xf0f31);
    if (c === 3) return String.fromCodePoint(0xf0590);
    if (c === 45 || c === 48) return String.fromCodePoint(0xf0591);
    if (c >= 51 && c <= 57) return String.fromCodePoint(0xf0597);
    if (c >= 61 && c <= 67) return String.fromCodePoint(0xf0596);
    if (c >= 71 && c <= 77) return String.fromCodePoint(0xf0598);
    if (c >= 80 && c <= 82) return String.fromCodePoint(0xf0597);
    if (c === 85 || c === 86) return String.fromCodePoint(0xf0598);
    if (c >= 95) return String.fromCodePoint(0xf0593);
    return String.fromCodePoint(0xf0590);
  }
  function _desc(c) {
    var m = {
      0: "Clear", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
      45: "Fog", 48: "Rime fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
      56: "Freezing drizzle", 57: "Freezing drizzle", 61: "Light rain", 63: "Rain", 65: "Heavy rain",
      66: "Freezing rain", 67: "Freezing rain", 71: "Light snow", 73: "Snow", 75: "Heavy snow",
      77: "Snow grains", 80: "Light showers", 81: "Showers", 82: "Heavy showers",
      85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm",
    };
    return m[c] || "";
  }

  Process {
    id: proc;
    stdout: StdioCollector { id: out }
    onExited: (exitCode) => {
      if (exitCode !== 0) return;
      var raw = (typeof out.text === "function" ? out.text() : out.text) || "{}";
      try {
        var d = JSON.parse(raw);
        var cur = d.current || {};
        root.temp = cur.temperature_2m;
        root.code = cur.weather_code;
        root.isDay = cur.is_day === 1;
        root.wind = cur.wind_speed_10m;
        root.gust = cur.wind_gusts_10m;
        root.windDir = cur.wind_direction_10m;

        var ht = d.hourly.time, hT = d.hourly.temperature_2m, hC = d.hourly.weather_code;
        var hW = d.hourly.wind_speed_10m, hD = d.hourly.wind_direction_10m;
        var now = new Date(), start = 0;
        for (var i = 0; i < ht.length; i++) {
          if (new Date(ht[i]) >= now) { start = Math.max(0, i - 1); break; }
        }
        var hs = [];
        for (var j = start; j < Math.min(ht.length, start + 12); j++)
          hs.push({ hour: ht[j].slice(11, 16), temp: Math.round(hT[j]), glyph: root._glyph(hC[j], true),
                    wind: Math.round(hW[j]), windDir: hD[j] });
        root.hourly = hs;

        var ds = [];
        for (var k = 0; k < Math.min(3, d.daily.time.length); k++)
          ds.push({
            label: k === 0 ? "Today" : Qt.formatDate(new Date(d.daily.time[k]), "ddd"),
            min: Math.round(d.daily.temperature_2m_min[k]),
            max: Math.round(d.daily.temperature_2m_max[k]),
            glyph: root._glyph(d.daily.weather_code[k], true),
            wind: Math.round(d.daily.wind_speed_10m_max[k]),
            gust: Math.round(d.daily.wind_gusts_10m_max[k]),
            windDir: d.daily.wind_direction_10m_dominant[k],
          });
        root.daily = ds;
      } catch (e) {
        // leave the last good reading in place
      }
    }
  }

  function refresh() {
    var url = "https://api.open-meteo.com/v1/forecast"
      + "?latitude=" + SunService.latitude + "&longitude=" + SunService.longitude
      + "&current=temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
      + "&hourly=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m"
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant"
      + "&timezone=auto&forecast_days=3";
    proc.command = ["curl", "-s", "--max-time", "8", url];
    proc.running = true;
  }

  Timer { interval: 20 * 60 * 1000; repeat: true; running: true; onTriggered: root.refresh(); }
  Connections { target: SunService; function onLatitudeChanged() { root.refresh(); } }
  Component.onCompleted: refresh();
}
