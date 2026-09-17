pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history via cliphist (fed by the `cliphist` systemd user service
// in default.nix). The launcher's clipboard section lists entries; picking
// one decodes it back onto the wl-clipboard.
Singleton {
  id: root;

  property var entries: [];   // [{ raw, preview, isImage }]

  Process {
    id: listProc;
    command: ["cliphist", "list"];
    stdout: StdioCollector { id: listOut }
    onExited: {
      var raw = (typeof listOut.text === "function" ? listOut.text() : listOut.text) || "";
      var out = [];
      raw.split("\n").forEach(function (line) {
        if (line === "") return;
        var tab = line.indexOf("\t");
        if (tab < 0) return;
        var preview = line.slice(tab + 1);
        out.push({
          raw: line,
          preview: preview.replace(/\s+/g, " ").trim(),
          isImage: /^\[\[\s*binary data/.test(preview) || /\b(png|jpe?g|gif|bmp|webp|tiff)\b/i.test(preview),
        });
      });
      root.entries = out;
    }
  }

  function refresh() { listProc.running = true; }

  function copy(raw) {
    copyProc.command = ["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", raw];
    copyProc.running = true;
  }
  Process { id: copyProc; }

  function remove(raw) {
    rmProc.command = ["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", raw];
    rmProc.running = true;
  }
  Process { id: rmProc; onExited: root.refresh(); }

  function wipe() { wipeProc.running = true; }
  Process { id: wipeProc; command: ["cliphist", "wipe"]; onExited: root.refresh(); }
}
