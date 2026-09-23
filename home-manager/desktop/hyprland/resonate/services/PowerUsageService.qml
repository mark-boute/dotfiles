pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// Where the laptop's power goes, for the power panel.
//
// Measured: CPU package (amdgpu hwmon "PPT": CPU cores + iGPU + uncore, a
// world-readable sysfs sensor), the dGPU (nvidia-smi, only while the panel is
// open — polling it in the background kept an awake card from ever idling back
// into D3cold) and total draw (the battery's discharge rate, so on battery
// only: on AC nothing in the charge path reports power). Everything else —
// screen, Wi-Fi, SSDs — has no power sensor readable without root, so it's
// shown as state (awake share, brightness, refresh) plus one unmeasured rest.
//
// Per-app figures are estimates: each app's share of CPU + iGPU busy time
// applied to the package power.
//
// Cost: the sensor sampler (two sysfs reads every 4s) always runs; the
// per-app/per-device snapshot (scripts/power_snapshot.sh, ~0.2s of CPU) runs
// every 5s only while the details are open, plus once at each unplug/plug-in
// to anchor the "since unplugged" window. None of it touches a device, so none
// of it can wake one.
Singleton {
  id: root;

  // Set by the power panel.
  property bool panelOpen: false;
  property bool detailsOpen: false;
  property string range: "minute";  // "minute" | "battery"
  property string tab: "apps";      // "apps" | "devices"

  // ---- sensors ------------------------------------------------------

  property real cpuWatts: 0;
  property var gpuWatts: null;      // null: awake but unmeasured (panel closed)
  property bool gpuAsleep: true;    // suspended, or awake with nothing holding it
  property var recent: [];          // [{t, cpu, gpu, total}] over the last ~70s

  // Since-unplug averages, reset at each unplug (or started at resonate start
  // when already on battery), frozen while on AC.
  property real accStart: 0;
  property real cpuSum: 0;
  property int cpuN: 0;
  property real gpuSum: 0;
  property int gpuN: 0;
  property real totSum: 0;
  property int totN: 0;

  // nvidia-smi keeps an awake card awake (it reset the idle timer every 4s),
  // so it runs at most every 30s, well past the card's autosuspend delay: a
  // card awake only because of the last reading falls asleep in between, and
  // the next check sees it suspended and skips the call.
  readonly property int nvsmiIntervalMs: 30000;
  property real _lastNvsmi: 0;
  property var _lastGpu: null;

  function _sample() {
    if (sensorProc.running) return;
    var due = root.panelOpen && Date.now() - root._lastNvsmi >= root.nvsmiIntervalMs;
    // Labelled lines ("C <µW>", "G <asleep|unknown|watts>") so a missing or
    // extra line can't shift the parse.
    sensorProc.command = ["sh", "-c",
      "for h in /sys/class/hwmon/hwmon*; do " +
      "  [ \"$(cat \"$h/name\" 2>/dev/null)\" = amdgpu ] && { echo \"C $(cat \"$h/power1_average\" 2>/dev/null)\"; break; }; " +
      "done; " +
      // runtime_status, not power_state — reading power_state resumes the card.
      "s=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null); " +
      "[ \"$s\" = suspended ] && { echo 'G asleep'; exit; }; " +
      "ls -l /proc/[0-9]*/fd 2>/dev/null | grep -q /dev/nvidia0 || { echo 'G asleep'; exit; }; " +
      "[ \"$1\" = 1 ] || { echo 'G unknown'; exit; }; " +
      "v=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null); echo \"G ${v:-failed}\"",
      "sh", due ? "1" : "0"];
    sensorProc.running = true;
  }

  Process {
    id: sensorProc;
    stdout: StdioCollector {
      onStreamFinished: root._onSensors((typeof this.text === "function") ? this.text() : this.text)
    }
  }
  Timer {
    interval: 4000;
    repeat: true;
    running: true;
    triggeredOnStart: true;
    onTriggered: root._sample();
  }

  function _onSensors(t) {
    var cpu = 0, g = "";
    var lines = (t || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i].trim();
      if (l.startsWith("C ")) cpu = (parseFloat(l.slice(2)) || 0) / 1e6;
      else if (l.startsWith("G ")) g = l.slice(2).trim();
    }
    var gpu = 0;
    if (g === "asleep" || g === "") {
      root.gpuAsleep = true;
    } else if (g === "unknown") {
      root.gpuAsleep = false;
      // Between readings, reuse the last one while it's recent.
      gpu = (root.panelOpen && Date.now() - root._lastNvsmi < root.nvsmiIntervalMs * 2) ? root._lastGpu : null;
    } else {
      root.gpuAsleep = false;
      gpu = parseFloat(g);
      if (isNaN(gpu)) gpu = null;
      root._lastNvsmi = Date.now();
      root._lastGpu = gpu;
    }
    var total = UPower.onBattery ? Math.abs(UPower.displayDevice.changeRate) : null;
    root.cpuWatts = cpu;
    root.gpuWatts = gpu;

    var now = Date.now();
    root.recent = root.recent.concat([{ t: now, cpu: cpu, gpu: gpu, total: total }])
      .filter(s => now - s.t <= 70000);

    if (UPower.onBattery) {
      root.cpuSum += cpu; root.cpuN++;
      if (gpu !== null) { root.gpuSum += gpu; root.gpuN++; }
      root.totSum += total; root.totN++;
    }
  }

  // ---- battery session (UPower's own 30s history, over D-Bus) --------

  property var session: [];         // [{t (s), w}] oldest first: the current or last discharge run

  Process {
    id: historyProc;
    command: ["sh", "-c",
      "p=$(upower -e | grep -m1 battery_) && gdbus call --system --dest org.freedesktop.UPower " +
      "--object-path \"$p\" --method org.freedesktop.UPower.Device.GetHistory rate 86400 2000"];
    stdout: StdioCollector {
      onStreamFinished: root._onHistory((typeof this.text === "function") ? this.text() : this.text)
    }
  }
  Timer {
    interval: 60000;
    repeat: true;
    running: root.panelOpen;
    onTriggered: historyProc.running = true;
  }

  function _onHistory(t) {
    // Newest first: "(uint32 <time>, <watts>, uint32 <state>)", state 2 = discharging.
    var re = /\((?:uint32 )?(\d+), ([0-9.eE+-]+), (?:uint32 )?(\d+)\)/g;
    var rows = [];
    var m;
    while ((m = re.exec(t || "")) !== null)
      rows.push({ t: +m[1], w: +m[2], s: +m[3] });
    // The clock runs ~2h fast for a while after each boot here (RTC kept in
    // local time), so UPower's stamps jump across boots: skip future stamps,
    // and end the run at any jump forward or gap over 30 min, where the times
    // on either side no longer line up.
    var nowS = Date.now() / 1000;
    var i = 0;
    while (i < rows.length && (rows[i].s !== 2 || rows[i].t > nowS + 60)) i++;
    var run = [];
    for (; i < rows.length && rows[i].s === 2; i++) {
      var prev = run.length ? run[run.length - 1].t : null;
      if (prev !== null && (rows[i].t >= prev || prev - rows[i].t > 1800)) break;
      run.push({ t: rows[i].t, w: rows[i].w });
    }
    root.session = run.reverse();
  }

  // ---- per-app / per-device snapshots --------------------------------

  property var battSnap: null;      // taken at unplug (or at start, if already on battery)
  property var battEnd: null;       // taken at plug-in; null while on battery
  property var recentSnaps: [];     // while the details are open, last ~70s
  property var latest: null;
  property bool _wantUnplug: false;
  property bool _wantPlug: false;
  property bool _again: false;

  function snapshot() {
    if (snapProc.running) root._again = true;
    else snapProc.running = true;
  }

  Process {
    id: snapProc;
    command: ["sh", Quickshell.shellPath("scripts/power_snapshot.sh")];
    stdout: StdioCollector {
      onStreamFinished: root._onSnap((typeof this.text === "function") ? this.text() : this.text)
    }
    onExited: if (root._again) { root._again = false; snapProc.running = true; }
  }
  Timer {
    interval: 5000;
    repeat: true;
    running: root.panelOpen && root.detailsOpen;
    triggeredOnStart: true;
    onTriggered: root.snapshot();
  }

  function _appKey(exe, comm, pid, ppid) {
    if (pid === 2 || ppid === 2) return "Kernel";
    var n = exe ? exe.slice(exe.lastIndexOf("/") + 1) : comm;
    if (n === "electron" || n === "") n = comm;
    return n.replace(/^\./, "").replace(/-wrap(p(ed?)?)?$|-wra$|-$/, "");
  }

  function _onSnap(text) {
    var snap = { t: Date.now(), tck: 100, procs: {}, gpu: {}, dev: {}, bright: null, monitors: [] };
    var exes = {};
    var lines = (text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].split(" ");
      switch (f[0]) {
      case "T": snap.tck = parseInt(f[1]) || 100; break;
      case "E": exes[f[1]] = f[2]; break;
      case "B": snap.bright = parseInt(f[1]); break;
      case "M": snap.monitors.push({ name: f[1], size: f[2], hz: parseInt(f[3]) }); break;
      case "D":
        snap.dev[f[1]] = { drv: f[2], status: f[3], act: +f[4], sus: +f[5] };
        break;
      case "G":
        snap.gpu[f[1] + "/" + f[2]] = { pid: f[1], ns: +f[3] };
        break;
      }
    }
    for (var j = 0; j < lines.length; j++) {
      var p = lines[j].split(" ");
      if (p[0] !== "P") continue;
      var pid = parseInt(p[1]);
      snap.procs["p" + p[1]] = { ticks: +p[3], key: root._appKey(exes[p[1]], p[4] || "", pid, parseInt(p[2])) };
    }

    if (root._wantUnplug) { root.battSnap = snap; root.battEnd = null; root._wantUnplug = false; }
    if (root._wantPlug) { if (root.battSnap) root.battEnd = snap; root._wantPlug = false; }
    if (root.panelOpen && root.detailsOpen)
      root.recentSnaps = root.recentSnaps.concat([snap]).filter(s => snap.t - s.t <= 70000);
    root.latest = snap;
    root._recompute();
  }

  // ---- derived lists -------------------------------------------------

  property var apps: [];            // [{name, watts, cpu (% of a core), gpu (%)}]
  property var devices: [];         // [{name, value, detail, measured}]
  property real windowStart: 0;     // ms epoch
  property real windowSecs: 0;

  onRangeChanged: _recompute();
  onDetailsOpenChanged: {
    if (!detailsOpen) root.recentSnaps = [];
  }
  onPanelOpenChanged: {
    if (panelOpen) {
      root._sample();
      historyProc.running = true;
    } else {
      root.recentSnaps = [];
    }
  }

  function _avg(key, from, to) {
    var sum = 0, n = 0;
    for (var i = 0; i < root.recent.length; i++) {
      var s = root.recent[i];
      if (s.t < from || s.t > to || s[key] === null) continue;
      sum += s[key]; n++;
    }
    return n ? sum / n : null;
  }

  readonly property var _deviceNames: ({
    nvidia: "dGPU", mt7921e: "Wi-Fi", mt7925e: "Wi-Fi", iwlwifi: "Wi-Fi", ath11k_pci: "Wi-Fi",
    nvme: "SSD", xhci_hcd: "USB", snd_hda_intel: "Audio", r8169: "Ethernet", amdxdna: "NPU",
  })

  function _recompute() {
    var base, end;
    if (root.range === "battery") {
      base = root.battSnap;
      end = root.battEnd || (UPower.onBattery ? root.latest : null);
    } else {
      base = root.recentSnaps.length ? root.recentSnaps[0] : null;
      end = root.recentSnaps.length ? root.recentSnaps[root.recentSnaps.length - 1] : null;
    }
    if (!base || !end || end.t - base.t < 1000) {
      root.apps = []; root.devices = []; root.windowSecs = 0;
      return;
    }
    var secs = (end.t - base.t) / 1000;
    root.windowStart = base.t;
    root.windowSecs = secs;

    // Package / dGPU / total power over the same window.
    var cpuW, gpuW, totW;
    if (root.range === "battery") {
      cpuW = root.cpuN ? root.cpuSum / root.cpuN : null;
      gpuW = root.gpuN ? root.gpuSum / root.gpuN : null;
      totW = root.totN ? root.totSum / root.totN : null;
    } else {
      cpuW = root._avg("cpu", base.t, end.t);
      gpuW = root._avg("gpu", base.t, end.t);
      totW = root._avg("total", base.t, end.t);
    }

    // Apps: CPU ticks and iGPU engine time per app over the window.
    var groups = {};
    var sumBusy = 0;
    for (var pid in end.procs) {
      var e = end.procs[pid], b = base.procs[pid];
      var cpuSec = (e.ticks - (b && b.key === e.key ? b.ticks : 0)) / end.tck;
      if (cpuSec <= 0) continue;
      if (!groups[e.key]) groups[e.key] = { cpu: 0, gpu: 0 };
      groups[e.key].cpu += cpuSec;
      sumBusy += cpuSec;
    }
    for (var k in end.gpu) {
      var g = end.gpu[k];
      var gpuSec = (g.ns - (base.gpu[k] ? base.gpu[k].ns : 0)) / 1e9;
      var owner = end.procs["p" + g.pid];
      if (gpuSec <= 0 || !owner) continue;
      if (!groups[owner.key]) groups[owner.key] = { cpu: 0, gpu: 0 };
      groups[owner.key].gpu += gpuSec;
      sumBusy += gpuSec;
    }
    var list = [];
    for (var name in groups) {
      var gr = groups[name];
      list.push({
        name: name,
        watts: (cpuW !== null && sumBusy > 0) ? cpuW * (gr.cpu + gr.gpu) / sumBusy : null,
        cpu: 100 * gr.cpu / secs,
        gpu: 100 * gr.gpu / secs,
        busy: gr.cpu + gr.gpu,
      });
    }
    list.sort((a, c) => c.busy - a.busy);
    root.apps = list.slice(0, 6);

    // Devices: measured rows first, then state for the unmeasured ones.
    function fmtW(w) { return w === null ? "—" : w.toFixed(1) + " W"; }
    function awakePct(addr) {
      var de = end.dev[addr], db = base.dev[addr];
      if (!de || !db) return null;
      var act = de.act - db.act, sus = de.sus - db.sus;
      return act + sus > 0 ? Math.round(100 * act / (act + sus)) : (de.status === "active" ? 100 : 0);
    }

    var rows = [];
    rows.push({ name: "CPU + iGPU", value: fmtW(cpuW), detail: "", measured: true });

    var gpuAddr = null;
    for (var a in end.dev) if (end.dev[a].drv === "nvidia") gpuAddr = a;
    var gpuAwake = gpuAddr ? awakePct(gpuAddr) : null;
    rows.push({
      name: "dGPU",
      value: gpuAwake === 0 ? "asleep" : (gpuW !== null && gpuW > 0 ? fmtW(gpuW) : "not measured"),
      detail: gpuAwake === null ? "" : "awake " + gpuAwake + "%",
      measured: true,
    });

    if (totW !== null) {
      var rest = Math.max(0, totW - (cpuW || 0) - (gpuW || 0));
      rows.push({ name: "Rest (unmeasured)", value: fmtW(rest), detail: "of " + fmtW(totW) + " total", measured: true });
    } else {
      rows.push({ name: "Rest (unmeasured)", value: "on AC", detail: "no total reading", measured: true });
    }

    var screen = end.monitors.length
      ? end.monitors.map(mo => mo.hz + " Hz").join(", ") : "";
    rows.push({
      name: end.monitors.length > 1 ? "Screens (" + end.monitors.length + ")" : "Screen",
      value: end.bright !== null ? end.bright + "%" : "",
      detail: screen,
      measured: false,
    });

    // Devices awake at some point in the window get a row each; the ones that
    // slept throughout are only counted, on one summary line.
    var awake = {}, asleep = {};
    var addrs = Object.keys(end.dev).sort();
    for (var x = 0; x < addrs.length; x++) {
      var nm = root._deviceNames[end.dev[addrs[x]].drv];
      if (!nm || nm === "dGPU") continue;
      var pct = awakePct(addrs[x]);
      if (pct === 0) { asleep[nm] = (asleep[nm] || 0) + 1; continue; }
      if (!awake[nm]) awake[nm] = [];
      awake[nm].push(pct === null ? 100 : pct);
    }
    for (var an in awake) {
      var list = awake[an];
      rows.push({
        name: list.length > 1 ? an + " ×" + list.length : an,
        value: "awake " + list.map(v => v + "%").join(" / "),
        detail: "",
        measured: false,
      });
    }
    if (BluetoothService.enabled)
      rows.push({ name: "Bluetooth", value: "on", detail: "", measured: false });
    else
      asleep["Bluetooth"] = 1;
    var sleepers = Object.keys(asleep).sort().map(k => asleep[k] > 1 ? k + " ×" + asleep[k] : k);
    if (sleepers.length)
      rows.push({ name: "Asleep or off: " + sleepers.join(", "), value: "", detail: "", measured: false });
    root.devices = rows;
  }

  // ---- unplug / plug-in anchors --------------------------------------

  function _onUnplug() {
    root.accStart = Date.now();
    root.cpuSum = 0; root.cpuN = 0; root.gpuSum = 0; root.gpuN = 0; root.totSum = 0; root.totN = 0;
    root._wantUnplug = true;
    root.snapshot();
  }

  Connections {
    target: UPower;
    function onOnBatteryChanged() {
      if (UPower.onBattery) {
        root._onUnplug();
      } else {
        root._wantPlug = true;
        root.snapshot();
      }
      historyProc.running = true;
    }
  }

  Component.onCompleted: {
    if (UPower.onBattery)
      root._onUnplug();
    historyProc.running = true;
  }
}
