pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Backs widgets/LauncherApp.qml — the SUPER launcher (a ControlPanel page).
//
//   apps  section: DesktopEntries; with no query, ordered by a most-used
//         frecency (launch count aged by recency, persisted to
//         ~/.config/resonate/launcher-usage.json); with a query, by match
//         relevance then that same frecency. ↑/↓ + Enter.
//   docs  section (Tab): zoxide (frecency dirs under ~/Documents) merged
//         with fd (files + dirs there). On a folder, Enter browses into it
//         (contents listed, Esc / ".." goes back up); Shift+Enter — and
//         plain Enter on a file — opens a MIME-aware "open with" list
//         (`gio mime`), Enter there launches the pick with the path.
//
// The Hyprland global shortcut `quickshell:launcher` (bound in
// hypr/keybinds.lua to SUPER+Space and a SUPER-release bind) toggles it.
Singleton {
  id: root;

  property bool open: false;
  property string query: "";
  property string section: "apps";   // "apps" | "docs" | "clip"
  property int appSel: 0;
  property int docSel: 0;
  property int clipSel: 0;

  // Non-empty while the open-with overlay is up: the path being opened.
  property string openWithPath: "";
  property int openWithSel: 0;

  // Non-empty while browsing a folder's contents (instead of the search).
  property string browseDir: "";

  readonly property string home: Quickshell.env("HOME") || "";
  readonly property string docsRoot: root.home + "/Documents";

  // Hyprland fires the bound global on both key-down and key-up of the
  // bind; debounce so one keypress is one toggle.
  property real _lastTrigger: 0;
  GlobalShortcut {
    appid: "quickshell";
    name: "launcher";
    onPressed: {
      var now = Date.now();
      if (now - root._lastTrigger < 250)
        return;
      root._lastTrigger = now;
      root.toggle();
    }
  }
  GlobalShortcut {
    appid: "quickshell";
    name: "clipboard";
    onPressed: {
      var now = Date.now();
      if (now - root._lastTrigger < 250)
        return;
      root._lastTrigger = now;
      if (root.open && root.section === "clip") root.hide();
      else root.showClipboard();
    }
  }

  // --- open/close -----------------------------------------------------

  function toggle() { root.open ? hide() : show(); }
  function show() {
    if (AssistantService.open) AssistantService.hide();
    root.query = "";
    root.section = "apps";
    root.appSel = 0;
    root.docSel = 0;
    root.clipSel = 0;
    root.openWithPath = "";
    root.openWithSel = 0;
    root.browseDir = "";
    root.open = true;
    root._runDocs();
  }
  function showClipboard() {
    show();
    root.section = "clip";
    ClipboardService.refresh();
  }
  function hide() { root.open = false; }

  // --- folder browsing --------------------------------------------

  function enterDir(path) {
    if (!path)
      return;
    root.browseDir = path;
    root.query = "";
    root.docSel = 1;   // past the ".." row that _runDocs prepends
    root._runDocs();
  }
  function upDir() {
    if (root.browseDir === "" || root.browseDir === root.docsRoot
        || root.browseDir.indexOf(root.docsRoot + "/") !== 0) {
      root.exitBrowse();
      return;
    }
    root.enterDir(root.browseDir.slice(0, root.browseDir.lastIndexOf("/")));
  }
  function exitBrowse() {
    root.browseDir = "";
    root.query = "";
    root.docSel = 0;
    root._runDocs();
  }

  function openWithAt(index) {
    var doc = root.docs[index];
    if (!doc || doc.isUp)
      return;
    root.openWithPath = doc.path;
    root.openWithSel = 0;
    root.query = "";
    root._runMime(doc.path);
  }

  // --- keyboard ------------------------------------------------------

  function move(delta) {
    if (root.openWithPath !== "") {
      var n = root.openWithApps.length;
      if (n > 0) root.openWithSel = (root.openWithSel + delta + n) % n;
    } else if (root.section === "apps") {
      var a = root.apps.length;
      if (a > 0) root.appSel = (root.appSel + delta + a) % a;
    } else if (root.section === "clip") {
      var c = root.clip.length;
      if (c > 0) root.clipSel = (root.clipSel + delta + c) % c;
    } else {
      var d = root.docs.length;
      if (d > 0) root.docSel = (root.docSel + delta + d) % d;
    }
  }

  function switchSection() {
    if (root.openWithPath !== "") return;
    root.section = root.section === "apps" ? "docs"
      : root.section === "docs" ? "clip" : "apps";
    if (root.section === "clip") ClipboardService.refresh();
  }

  // Clipboard entries filtered by the query.
  readonly property var clip: {
    var q = root.query.trim().toLowerCase();
    var all = ClipboardService.entries;
    if (q === "") return all;
    return all.filter(function (e) { return e.preview.toLowerCase().indexOf(q) >= 0; });
  }
  onClipChanged: if (root.clipSel >= clip.length) root.clipSel = 0;

  // shift: Shift+Enter — on a folder, force the open-with list instead of
  // browsing into it.
  function activate(shift) {
    if (root.openWithPath !== "") {
      var pick = root.openWithApps[root.openWithSel];
      if (pick && pick.isDefault)
        Quickshell.execDetached(PlatformProfileService.launchCommand(["xdg-open", root.openWithPath]));
      else if (pick && pick.entry)
        Quickshell.execDetached(PlatformProfileService.launchCommand(["gtk-launch", pick.entry.id, root.openWithPath]));
      root.hide();
      return;
    }
    if (root.section === "apps") {
      var e = root.apps[root.appSel];
      if (e) {
        root._bump(e.id);
        Quickshell.execDetached(PlatformProfileService.launchCommand(e.command, e.workingDirectory));
        root.hide();
      }
      return;
    }
    if (root.section === "clip") {
      var c = root.clip[root.clipSel];
      if (c) { ClipboardService.copy(c.raw); root.hide(); }
      return;
    }
    var doc = root.docs[root.docSel];
    if (!doc)
      return;
    if (doc.isUp)
      root.upDir();
    else if (doc.isDir && !shift)
      root.enterDir(doc.path);
    else
      root.openWithAt(root.docSel);
  }

  // Escape / back: close the open-with overlay first, then step out of a
  // browsed folder, then close the launcher.
  function back() {
    if (root.openWithPath !== "") {
      root.openWithPath = "";
      root.query = "";
    } else if (root.browseDir !== "") {
      root.upDir();
    } else {
      root.hide();
    }
  }

  // --- apps ---------------------------------------------------------

  readonly property var apps: {
    var q = root.query.trim().toLowerCase();
    var all = DesktopEntries.applications.values;
    var scored = [];
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (!e || e.noDisplay) continue;
      var s = root._score(e, q);
      if (s > 0) scored.push({ e: e, s: s });
    }
    scored.sort(function(a, b) {
      return (b.s - a.s)
        || (root._frecency(b.e.id) - root._frecency(a.e.id))
        || a.e.name.localeCompare(b.e.name);
    });
    return scored.slice(0, 60).map(function(x) { return x.e; });
  }
  onAppsChanged: if (root.appSel >= apps.length) root.appSel = 0;

  // --- most-used ordering (persisted) ------------------------------

  property var _usage: ({});   // id -> { count, last (ms) }

  function _frecency(id) {
    var u = root._usage[id];
    if (!u) return 0;
    var age = Date.now() - (u.last || 0);
    var h = 3600000, d = 24 * h;
    var w = age < h ? 4 : age < d ? 2 : age < 7 * d ? 1 : age < 30 * d ? 0.5 : 0.25;
    return (u.count || 0) * w;
  }

  function _bump(id) {
    if (!id) return;
    var prev = root._usage[id];
    var next = Object.assign({}, root._usage);
    next[id] = { count: (prev ? prev.count : 0) + 1, last: Date.now() };
    root._usage = next;
    usageAdapter.apps = next;
    usageStore.writeAdapter();
  }

  FileView {
    id: usageStore;
    path: (root.home || "") + "/.config/resonate/launcher-usage.json";
    printErrors: false;
    onLoaded: root._usage = usageAdapter.apps || ({});
    JsonAdapter { id: usageAdapter; property var apps: ({}); }
  }

  Component.onCompleted: usageStore.reload();

  function _score(e, q) {
    if (q === "") return 1;
    var name = (e.name || "").toLowerCase();
    var hay = name + " " + (e.genericName || "").toLowerCase() + " "
      + (e.comment || "").toLowerCase() + " "
      + (e.keywords || []).join(" ").toLowerCase();
    if (name === q) return 1000;
    if (name.indexOf(q) === 0) return 600;
    var toks = q.split(/\s+/);
    for (var i = 0; i < toks.length; i++)
      if (hay.indexOf(toks[i]) < 0) return 0;
    if (name.indexOf(q) >= 0) return 200;
    if ((" " + name).indexOf(" " + toks[0]) >= 0) return 120;
    return 20;
  }

  readonly property var _entryById: {
    var m = ({});
    var all = DesktopEntries.applications.values;
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (e && e.id) m[e.id] = e;
    }
    return m;
  }

  // --- documents (zoxide + fd) ------------------------------------

  property var docs: [];   // [{ path, name, dir, isDir }]

  Timer { id: docsDebounce; interval: 140; onTriggered: root._runDocs(); }
  onQueryChanged: {
    if (!root.open) return;
    if (root.openWithPath === "") docsDebounce.restart();
  }

  Process {
    id: docsProc;
    stdout: StdioCollector { id: docsOut }
    onExited: {
      var raw = (typeof docsOut.text === "function" ? docsOut.text() : docsOut.text) || "";
      var seen = ({});
      var list = [];
      raw.split("\n").forEach(function(line) {
        if (line === "") return;
        var isDir = line.charAt(line.length - 1) === "/";
        var p = isDir ? line.slice(0, -1) : line;
        if (p === "" || seen[p]) return;
        seen[p] = true;
        var slash = p.lastIndexOf("/");
        list.push({
          path: p,
          name: p.slice(slash + 1),
          dir: p.slice(0, slash).replace(root.home, "~"),
          isDir: isDir,
        });
      });
      list = list.slice(0, 40);
      if (root.browseDir !== "") {
        list.unshift({
          path: root.browseDir.slice(0, root.browseDir.lastIndexOf("/")),
          name: "..", dir: "", isDir: true, isUp: true,
        });
      }
      root.docs = list;
      if (root.docSel >= root.docs.length)
        root.docSel = Math.max(0, root.docs.length - 1);
    }
  }

  function _runDocs() {
    if (!root.open || root.home === "") return;
    var q = root.query.trim();
    // fd already suffixes "/" to directories; only zoxide's plain paths need it.
    if (root.browseDir !== "") {
      // Immediate contents of the browsed folder, dirs first, query-filtered.
      var browse =
        'd="$1"; q="$2"; [ -d "$d" ] || exit 0;\n' +
        'if [ -n "$q" ]; then fd -d1 -i --fixed-strings --absolute-path -- "$q" "$d" 2>/dev/null;\n' +
        'else fd -d1 --absolute-path . "$d" 2>/dev/null; fi | ' +
        'sort | awk \'/\\/$/{a=a $0 ORS} !/\\/$/{b=b $0 ORS} END{printf "%s%s", a, b}\'';
      docsProc.command = ["sh", "-c", browse, "sh", root.browseDir, q];
    } else {
      var search =
        'docs="$HOME/Documents"; [ -d "$docs" ] || exit 0; q="$1";\n' +
        'zoxide query -l 2>/dev/null | grep -F "$docs" | ' +
          '{ if [ -n "$q" ]; then grep -iF -- "$q"; else cat; fi; } | ' +
          'head -n 12 | sed "s:/*$:/:";\n' +
        '[ -n "$q" ] && fd --absolute-path -i --fixed-strings --max-results 30 -- "$q" "$docs" 2>/dev/null';
      docsProc.command = ["sh", "-c", search, "sh", q];
    }
    docsProc.running = true;
  }

  // --- open with (MIME-aware) -----------------------------------

  property string openWithMime: "";
  property var _mimeIds: [];   // desktop ids gio reports for the mime type

  Process {
    id: mimeProc;
    stdout: StdioCollector { id: mimeOut }
    onExited: {
      var raw = (typeof mimeOut.text === "function" ? mimeOut.text() : mimeOut.text) || "";
      var lines = raw.split("\n");
      root.openWithMime = (lines.length > 0 ? lines[0] : "").trim();
      var ids = [];
      var inList = false;
      for (var i = 1; i < lines.length; i++) {
        var ln = lines[i];
        if (/^(Registered|Recommended) applications:/.test(ln)) { inList = true; continue; }
        if (/^Default application/.test(ln)) {
          var dm = ln.match(/([\w.\-]+)\.desktop/);
          if (dm) ids.push(dm[1]);
          continue;
        }
        var t = ln.trim();
        if (inList && /\.desktop$/.test(t)) ids.push(t.replace(/\.desktop$/, ""));
      }
      root._mimeIds = ids;
    }
  }

  function _runMime(path) {
    var script =
      'p="$1"; ' +
      'if [ -d "$p" ]; then m="inode/directory"; ' +
      'else m=$(xdg-mime query filetype "$p" 2>/dev/null); fi; ' +
      'echo "$m"; ' +
      '[ -n "$m" ] && gio mime "$m" 2>/dev/null';
    mimeProc.command = ["sh", "-c", script, "sh", path];
    mimeProc.running = true;
  }

  // [{ isDefault }] then matched entries then the rest, filtered by query.
  readonly property var openWithApps: {
    if (root.openWithPath === "") return [];
    var q = root.query.trim().toLowerCase();
    var out = [{ isDefault: true, entry: null,
                 label: "Open" + (root.openWithMime !== "" ? "  ·  " + root.openWithMime : "") }];

    var picked = ({});
    for (var i = 0; i < root._mimeIds.length; i++) {
      var e = root._entryById[root._mimeIds[i]];
      if (e && !picked[e.id]) { picked[e.id] = true; out.push({ isDefault: false, entry: e, label: e.name }); }
    }
    var all = DesktopEntries.applications.values;
    var rest = [];
    for (var j = 0; j < all.length; j++) {
      var a = all[j];
      if (!a || a.noDisplay || picked[a.id]) continue;
      rest.push(a);
    }
    rest.sort(function(x, y) { return x.name.localeCompare(y.name); });
    for (var k = 0; k < rest.length; k++)
      out.push({ isDefault: false, entry: rest[k], label: rest[k].name });

    if (q === "") return out;
    return out.filter(function(o) {
      return o.isDefault || o.label.toLowerCase().indexOf(q) >= 0;
    });
  }
  onOpenWithAppsChanged: if (root.openWithSel >= openWithApps.length) root.openWithSel = 0;
}
