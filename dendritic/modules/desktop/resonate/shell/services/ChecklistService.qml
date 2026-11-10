pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import qs

// Backs the ControlPanel's checklist section. Reads the tree from markboute.nl's
// checklist API (apps/checklist) with a static bearer token — see Config.qml —
// and ticks rows back with debounced PATCHes. Deliberately mirrors the pure
// helpers in that repo's lib/checklist.ts (rowKey / tableCounts / groupCounts)
// rather than importing anything.
//
// `revision` bumps on every local change. The tree objects are mutated in
// place (QML does not deep-watch), so the count/checked helpers below take a
// trailing `rev` arg they ignore: callers pass `revision` there so the binding
// re-evaluates when a tick lands.
Singleton {
  id: root;

  property var tree: [];
  property bool configured: false;
  property bool loading: false;
  property string error: "";
  property int revision: 0;   // structural change (tree reloaded with a real diff)
  property int checkRev: 0;   // a checkbox toggled — cheap, no Repeater rebuild

  // Which of Config.checklistUrls last answered a GET — reused for PATCHes.
  // Empty until the first success; reload() always re-walks from the top.
  property string activeUrl: "";
  property int _tryIdx: 0;
  property var _unreachable: [];

  function _hostOf(url) { return url.replace(/^https?:\/\//, ""); }

  // tableId -> checked map awaiting a PATCH, and the drain queue.
  property var _dirty: ({});
  property var _queue: [];

  // Last raw tree JSON, to skip rebuilding (and losing expand state) on an
  // unchanged periodic refresh. And per-node expand state, kept here so it
  // survives the Repeater rebuild a real change does cause.
  property string _lastRaw: "";
  property var _expanded: ({});
  property int uiRevision: 0;   // bumps on expand/collapse (see flatten())

  function isExpanded(id, dflt) { return (id in root._expanded) ? root._expanded[id] : dflt; }
  function toggleExpanded(id, dflt) {
    root._expanded[id] = !isExpanded(id, dflt);
    root.uiRevision++;
  }

  // The visible tree flattened to a list the panel renders with one flat
  // Repeater (QML/quickshell forbids a self-instantiating component). One entry
  // per group and table header, plus a "grid" entry for each expanded table —
  // ChecklistTable draws the whole table there. Structural only: counts and
  // checked state are read live by the delegates against checkRev, so a tick
  // never rebuilds this list. `rev`/`uiRev` are ignored — callers pass
  // revision/uiRevision so the binding recomputes when structure/expansion
  // changes.
  function flatten(rev, uiRev) {
    var out = [];
    _flattenInto(out, root.tree, 0);
    return out;
  }
  function _flattenInto(out, nodes, depth) {
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      var exp = isExpanded(n.id, depth === 0);
      out.push({ kind: n.type, id: n.id, name: n.name, depth: depth, expanded: exp });
      if (!exp) continue;
      if (n.type === "group") _flattenInto(out, n.children, depth + 1);
      else out.push({ kind: "grid", tableId: n.id, depth: depth + 1 });
    }
  }

  function nodeById(id) { return _findNode(root.tree, id); }
  function _findNode(nodes, id) {
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (n.id === id) return n;
      if (n.type === "group") { var f = _findNode(n.children, id); if (f) return f; }
    }
    return null;
  }

  // A cell value that should render as an image (ported from lib/checklist.ts).
  function imgUrl(v) {
    if (typeof v !== "string") return "";
    var s = v.trim();
    if (s.startsWith("//")) s = "https:" + s;
    if (s.startsWith("data:image/")) return s;
    if (/^https?:\/\//i.test(s) && /\.(png|jpe?g|gif|webp|svg|avif|bmp)(\?[^#]*)?(#.*)?$/i.test(s)) return s;
    return "";
  }

  // --- load ---------------------------------------------------------------

  function reload() {
    if (!root.configured) return;
    root._tryIdx = 0;
    root._unreachable = [];
    root.error = "";
    root.loading = true;
    _attempt();
  }

  // Fire a tree GET against Config.checklistUrls[_tryIdx].
  function _attempt() {
    var urls = Config.checklistUrls;
    if (root._tryIdx >= urls.length) {
      root.loading = false;
      if (root.error === "")
        root.error = "Can't reach " + root._unreachable.join(" or ") + ".";
      return;
    }
    treeProc.command = ["sh", "-c",
      'tok=$(cat "$1" 2>/dev/null); [ -n "$tok" ] || exit 3; ' +
      'curl -sS --connect-timeout 2 --max-time 8 -w "\\nHTTP:%{http_code}" ' +
      '-H "Authorization: Bearer $tok" "$2/api/checklist/tree"',
      "sh", Config.checklistTokenFile, urls[root._tryIdx]];
    treeProc.running = true;
  }

  Component.onCompleted: tokenProbe.running = true;

  Process {
    id: tokenProbe;
    command: ["sh", "-c", 'test -s "$1" && echo yes || echo no', "sh", Config.checklistTokenFile];
    stdout: StdioCollector {
      onStreamFinished: {
        var t = (typeof this.text === "function") ? this.text() : this.text;
        root.configured = (t || "").trim() === "yes";
        if (root.configured) root.reload();
        else root.error = "Checklist token not configured.";
      }
    }
  }

  // curl prints the body then a final line "HTTP:<code>" ("HTTP:000" if it never
  // got a response — DNS failure, refused, timeout). All the URLs hit the same
  // backend, so a 401 is a real token problem and stops the walk; only a failed
  // connection or a 5xx falls through to the next URL.
  Process {
    id: treeProc;
    stdout: StdioCollector { id: treeOut }
    onExited: (code, status) => {
      if (code === 3) { root.loading = false; root.error = "Checklist token not configured."; return; }

      var base = Config.checklistUrls[root._tryIdx];
      var raw = (typeof treeOut.text === "function" ? treeOut.text() : treeOut.text) || "";
      var m = raw.match(/\nHTTP:(\d+)\s*$/);
      var http = m ? parseInt(m[1]) : 0;
      var body = m ? raw.slice(0, m.index) : raw;

      if (http === 401 || http === 403) {
        root.loading = false;
        root.error = "Checklist token rejected (HTTP " + http + ").";
        return;
      }

      if (http === 200) {
        try {
          var data = JSON.parse(body || "{}");
          var next = JSON.stringify(data.tree || []);
          if (next !== root._lastRaw) {
            root._lastRaw = next;
            root.tree = (data.tree || []).map(root._normalize);
            root.revision++;
          }
          root.activeUrl = base;
          root.error = "";
        } catch (e) {
          root.error = "Bad response from " + root._hostOf(base) + ".";
        }
        root.loading = false;
        return;
      }

      // Unreachable or server error → remember why, try the next URL.
      if (http === 0) root._unreachable.push(root._hostOf(base));
      else root.error = root._hostOf(base) + " returned HTTP " + http + ".";
      root._tryIdx++;
      _attempt();
    }
  }

  function _normalize(n) {
    if (n && n.type === "group")
      return {
        type: "group", id: n.id, name: n.name || "Untitled",
        collapsed: !!n.collapsed,
        children: (n.children || []).map(root._normalize),
      };
    return {
      type: "table", id: n.id, name: n.name || "Untitled",
      collapsed: !!n.collapsed,
      columns: n.columns || [],
      keyColumn: n.keyColumn || 0,
      rows: n.rows || [],
      checked: n.checked || ({}),
    };
  }

  // Periodic refresh — a shared list can change under us. Cheap; the tree is small.
  Timer {
    interval: 120000; repeat: true; running: root.configured;
    onTriggered: root.reload();
  }

  // --- helpers (ported from lib/checklist.ts) ----------------------------

  function rowKey(t, row, idx) {
    var raw = row[t.keyColumn];
    var k = String(raw === undefined || raw === null ? "" : raw).trim();
    return k || (" row" + idx);
  }

  function rowLabel(t, idx) {
    var v = t.rows[idx][t.keyColumn];
    return String(v === undefined || v === null ? "" : v) || ("Row " + (idx + 1));
  }

  function isRowChecked(t, idx, rev) {
    return !!t.checked[rowKey(t, t.rows[idx], idx)];
  }

  function tableCounts(t) {
    var done = 0;
    for (var i = 0; i < t.rows.length; i++)
      if (t.checked[rowKey(t, t.rows[i], i)]) done++;
    return { done: done, total: t.rows.length };
  }

  // `rev` ignored — callers pass checkRev (and/or revision) so header/tile
  // progress re-evaluates on a tick without rebuilding anything.
  function nodeCounts(n, rev) {
    if (!n) return { done: 0, total: 0 };
    if (n.type === "table") return tableCounts(n);
    var done = 0, total = 0;
    for (var i = 0; i < n.children.length; i++) {
      var c = nodeCounts(n.children[i]);
      done += c.done; total += c.total;
    }
    return { done: done, total: total };
  }

  function rootCounts(rev) {
    var done = 0, total = 0;
    for (var i = 0; i < root.tree.length; i++) {
      var c = nodeCounts(root.tree[i]);
      done += c.done; total += c.total;
    }
    return { done: done, total: total };
  }

  // --- ticking ----------------------------------------------------------

  function setRowChecked(tableId, rowIdx, value) {
    var t = nodeById(tableId);
    if (!t || t.type !== "table") return;
    var key = rowKey(t, t.rows[rowIdx], rowIdx);
    if (value) t.checked[key] = true;
    else delete t.checked[key];
    root.checkRev++;
    root._dirty[tableId] = t.checked;
    patchDebounce.restart();
  }

  Timer {
    id: patchDebounce;
    interval: 500;
    onTriggered: {
      for (var id in root._dirty) root._queue.push({ id: id, checked: root._dirty[id] });
      root._dirty = ({});
      root._drain();
    }
  }

  function _drain() {
    if (patchProc.running || root._queue.length === 0) return;
    var job = root._queue.shift();
    var base = root.activeUrl || Config.checklistUrls[0];
    // Set command imperatively rather than as a binding — it must be exactly
    // this job's values at the moment `running` flips true.
    patchProc.command = ["sh", "-c",
      'tok=$(cat "$1" 2>/dev/null); [ -n "$tok" ] || exit 3; ' +
      'curl -sfS --connect-timeout 2 --max-time 10 -X PATCH -H "Authorization: Bearer $tok" ' +
      '-H "Content-Type: application/json" --data-raw "$2" "$3/api/checklist/nodes/$4"',
      "sh", Config.checklistTokenFile,
      JSON.stringify({ checked: job.checked }), base, job.id];
    patchProc.running = true;
  }

  Process {
    id: patchProc;
    onExited: (code, status) => {
      if (code !== 0) root.error = "Couldn't save a checklist change.";
      root._drain();
    }
  }
}
