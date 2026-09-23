pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Backs widgets/AssistantApp.qml — the SUPER+A assistant (a ControlPanel page).
//
// Each message runs `assistant-chat` (scripts/assistant-chat.sh), which starts
// or resumes a headless Claude session (no tools) and streams stream-json
// events; this parses them into `streamText` and, on the final `result`, a
// message. The conversation (and Claude's session id) persist to
// $XDG_STATE_HOME/resonate/assistant/conversation.json.
//
// The weekly grocery job (assistant-weekly) parks questions it could not
// resolve on its own in pending.json; opening the assistant adopts that
// session so the user's answers continue the same conversation.
//
// The Hyprland global shortcut `quickshell:assistant` (SUPER+A, bound in
// hypr/keybinds.lua) toggles it; `qs -c resonate ipc call assistant open` too.
Singleton {
  id: root;

  property bool open: false;
  property bool busy: false;
  property string error: "";
  property string sessionId: "";
  property bool offersSent: false;
  property var messages: [];        // [{ role: "user" | "assistant", text }]
  property string streamText: "";
  property string mailStatus: "";   // "" | "sending" | "sent" | "error: ..."
  property bool _ready: false;

  readonly property string home: Quickshell.env("HOME") || "";
  readonly property string stateDir:
    (Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")) + "/resonate/assistant";

  // Hyprland fires the bound global on both key-down and key-up of the
  // bind; debounce so one keypress is one toggle.
  property real _lastTrigger: 0;
  GlobalShortcut {
    appid: "quickshell";
    name: "assistant";
    onPressed: {
      var now = Date.now();
      if (now - root._lastTrigger < 250)
        return;
      root._lastTrigger = now;
      root.toggle();
    }
  }

  IpcHandler {
    target: "assistant";
    function open(): void { root.show(); }
    function toggle(): void { root.toggle(); }
  }

  // --- open/close -----------------------------------------------------

  function toggle() { root.open ? hide() : show(); }
  function show() {
    if (LauncherService.open) LauncherService.hide();
    if (root._ready) pendingFile.reload();
    root.open = true;
  }
  function hide() { root.open = false; }

  // --- sending --------------------------------------------------------

  // Offers are ~20k tokens, so they only ride along when the message is
  // about food/shopping, and only once per session.
  function _wantsOffers(text) {
    return /grocer|boodschap|supermarkt|aanbied|bonus|discount|\bdeals?\b|\baldi\b|albert|\bah\b|meal plan|dinner|diner|recip|recept|shopping list/i.test(text);
  }

  function send(text) {
    text = (text || "").trim();
    if (text === "" || root.busy) return;
    root.error = "";
    root.mailStatus = "";
    root.messages = root.messages.concat([{ role: "user", text: text }]);
    root.streamText = "";
    root.busy = true;

    var args = ["assistant-chat"];
    if (root.sessionId !== "") args.push("--session", root.sessionId);
    if (!root.offersSent && root._wantsOffers(text)) {
      args.push("--offers");
      root.offersSent = true;
    }
    args.push(text);
    root._persist();

    chatProc.command = args;
    chatProc.running = true;
  }

  function cancel() {
    if (root.busy) chatProc.running = false;
  }

  function newChat() {
    if (root.busy) chatProc.running = false;
    root.sessionId = "";
    root.offersSent = false;
    root.messages = [];
    root.streamText = "";
    root.error = "";
    root.mailStatus = "";
    root._persist();
  }

  Process {
    id: chatProc;
    stdout: SplitParser { onRead: (line) => root._onLine(line) }
    stderr: StdioCollector { id: chatErr }
    onExited: (code, status) => root._onExit(code)
  }

  function _onLine(line) {
    if (line === "") return;
    var ev;
    try { ev = JSON.parse(line); } catch (e) { return; }

    if (ev.type === "system" && ev.subtype === "init" && ev.session_id) {
      root.sessionId = ev.session_id;
    } else if (ev.type === "stream_event" && ev.event
               && ev.event.type === "content_block_delta"
               && ev.event.delta && ev.event.delta.type === "text_delta") {
      root.streamText += ev.event.delta.text;
    } else if (ev.type === "result") {
      var text = (typeof ev.result === "string" && ev.result !== "") ? ev.result : root.streamText;
      if (ev.session_id) root.sessionId = ev.session_id;
      if (ev.is_error) {
        root.error = text || "The assistant reported an error.";
      } else {
        root.messages = root.messages.concat([{ role: "assistant", text: text }]);
        root.streamText = "";
      }
      root._persist();
    }
  }

  function _onExit(code) {
    root.busy = false;
    // Stopped mid-answer: keep what arrived rather than dropping it.
    if (root.streamText !== "") {
      root.messages = root.messages.concat([{ role: "assistant", text: root.streamText + "\n\n*(stopped)*" }]);
      root.streamText = "";
      root._persist();
    } else if (code !== 0 && root.error === "") {
      var err = (typeof chatErr.text === "function" ? chatErr.text() : chatErr.text) || "";
      root.error = err.trim().split("\n").slice(-2).join(" ") || ("assistant-chat exited with code " + code);
    }
  }

  // --- email ----------------------------------------------------------

  // `body` is the content of an ```email block: "Subject: ..." + markdown.
  function sendEmail(body) {
    if (root.mailStatus === "sending") return;
    root.mailStatus = "sending";
    mailProc.command = ["sh", "-c",
      'printf "%s\\n" "$1" | assistant-mail && rm -f "$2/pending.json"',
      "sh", body, root.stateDir];
    mailProc.running = true;
  }

  Process {
    id: mailProc;
    stderr: StdioCollector { id: mailErr }
    onExited: (code, status) => {
      if (code === 0) { root.mailStatus = "sent"; return; }
      var err = (typeof mailErr.text === "function" ? mailErr.text() : mailErr.text) || "";
      root.mailStatus = "error: " + (err.trim().split("\n").slice(-1)[0] || ("exit " + code));
    }
  }

  // --- persistence ----------------------------------------------------

  function _persist() {
    if (!root._ready) return;
    conv.sessionId = root.sessionId;
    conv.offersSent = root.offersSent;
    conv.messages = root.messages.slice(-60);
    store.writeAdapter();
  }

  FileView {
    id: store;
    path: root.stateDir + "/conversation.json";
    printErrors: false;
    onLoaded: {
      root.sessionId = conv.sessionId || "";
      root.offersSent = !!conv.offersSent;
      root.messages = conv.messages || [];
      root._ready = true;
    }
    onLoadFailed: root._ready = true;
    JsonAdapter {
      id: conv;
      property string sessionId: "";
      property bool offersSent: false;
      property var messages: [];
    }
  }

  // Questions the weekly job could not settle on its own. Only adopted once
  // the stored conversation has loaded (else it would be overwritten by it).
  FileView {
    id: pendingFile;
    path: root.stateDir + "/pending.json";
    printErrors: false;
    onLoaded: {
      if (!root._ready || pending.session_id === "" || pending.session_id === root.sessionId) return;
      root.sessionId = pending.session_id;
      root.offersSent = true;
      root.messages = [{ role: "assistant", text: pending.text }];
      root.error = "";
      root.mailStatus = "";
      root._persist();
      Quickshell.execDetached(["rm", "-f", root.stateDir + "/pending.json"]);
    }
    JsonAdapter {
      id: pending;
      property string session_id: "";
      property string text: "";
    }
  }

  Process {
    id: mkdirProc;
    command: ["mkdir", "-p", root.stateDir];
    onExited: store.reload();
  }
  Component.onCompleted: mkdirProc.running = true;
}
