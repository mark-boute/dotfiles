import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// The SUPER+A assistant, rendered as a ControlPanel page (openApp ===
// "assistant") so it morphs the centre notch like every other app. State and
// the Claude process live in services/AssistantService.qml; this is the
// message list, the input and the "email this plan" card.
Item {
  id: root;

  readonly property int appWidth: 560;
  implicitWidth: appWidth;
  implicitHeight: 480;

  readonly property var svc: Services.AssistantService;

  // Escape with nothing to cancel or close: step back to the panel's home.
  signal backRequested();

  // Stored messages plus the answer currently streaming in.
  readonly property var rows: {
    var r = root.svc.messages.slice();
    if (root.svc.busy) r.push({ role: "assistant", text: root.svc.streamText, streaming: true });
    return r;
  }

  // The assistant delivers a finished grocery plan as a fenced ```email block
  // ("Subject: ..." then markdown); see assistant/system-prompt.md.
  function emailOf(text) {
    var m = /```email[ \t]*\n([\s\S]*?)\n```/.exec(text || "");
    return m ? m[1].trim() : "";
  }
  function displayOf(text) {
    return (text || "").replace(/```email[ \t]*\n([\s\S]*?)\n```/, "---\n\n$1\n\n---");
  }

  function submit() {
    root.svc.send(input.text);
    input.text = "";
  }

  function handleKey(e) {
    switch (e.key) {
    case Qt.Key_Return:
    case Qt.Key_Enter:
      if (e.modifiers & Qt.ShiftModifier) { e.accepted = false; break; }
      root.submit();
      e.accepted = true;
      break;
    case Qt.Key_Escape:
      if (root.svc.busy) root.svc.cancel();
      else if (root.svc.open) root.svc.hide();
      else root.backRequested();
      e.accepted = true;
      break;
    case Qt.Key_N:
      if (e.modifiers & Qt.ControlModifier) { root.svc.newChat(); e.accepted = true; }
      else e.accepted = false;
      break;
    default: e.accepted = false;
    }
  }

  Component.onCompleted: Qt.callLater(() => input.forceActiveFocus());
  Connections {
    target: root.svc;
    function onOpenChanged() {
      if (root.svc.open) Qt.callLater(() => input.forceActiveFocus());
    }
    function onMessagesChanged() { Qt.callLater(list.positionViewAtEnd); }
    function onStreamTextChanged() { Qt.callLater(list.positionViewAtEnd); }
  }

  ColumnLayout {
    anchors.fill: parent;
    spacing: Theme.defaultSpacing;

    // --- conversation ---
    ListView {
      id: list;
      Layout.fillWidth: true;
      Layout.fillHeight: true;
      clip: true;
      spacing: 10;
      boundsBehavior: Flickable.StopAtBounds;
      model: root.rows;
      delegate: rowDelegate;

      Text {
        anchors.centerIn: parent;
        width: parent.width * 0.8;
        visible: root.rows.length === 0;
        horizontalAlignment: Text.AlignHCenter;
        wrapMode: Text.Wrap;
        text: "Ask about your week, your calendar, or what to cook.\nTry: “plan my groceries for the week”";
        color: CurrentTheme.subtext;
        font.pixelSize: 12;
      }
    }

    // --- input ---
    Rectangle {
      Layout.fillWidth: true;
      implicitHeight: Math.min(120, Math.max(40, input.contentHeight + 22));
      radius: 10;
      color: CurrentTheme.backgroundGlass;
      border.width: 1;
      border.color: CurrentTheme.accent;

      TextEdit {
        id: input;
        anchors.fill: parent;
        anchors.margins: 11;
        color: CurrentTheme.text;
        font.pixelSize: 14;
        wrapMode: TextEdit.Wrap;
        selectByMouse: true;
        selectionColor: CurrentTheme.accent;
        selectedTextColor: CurrentTheme.background;
        clip: true;
        focus: true;
        Keys.priority: Keys.BeforeItem;
        Keys.onPressed: (e) => root.handleKey(e);

        Text {
          visible: input.text === "";
          text: root.svc.busy ? "Thinking…" : "Ask the assistant…";
          color: CurrentTheme.subtext;
          font: input.font;
        }
      }
    }

    // --- status + controls ---
    RowLayout {
      Layout.fillWidth: true;
      spacing: 8;

      Text {
        Layout.fillWidth: true;
        text: root.svc.error !== "" ? root.svc.error
          : root.svc.busy ? "Thinking…"
          : "Enter sends · Shift+Enter new line · Esc closes";
        color: root.svc.error !== "" ? CurrentTheme.danger : CurrentTheme.subtext;
        font.pixelSize: 10;
        elide: Text.ElideRight;
      }

      Repeater {
        model: [
          { label: "Stop", shown: root.svc.busy, act: "stop" },
          { label: "New chat", shown: root.svc.messages.length > 0 && !root.svc.busy, act: "new" },
        ];
        delegate: Rectangle {
          required property var modelData;
          visible: modelData.shown;
          implicitHeight: 22;
          implicitWidth: chipText.implicitWidth + 18;
          radius: 11;
          color: CurrentTheme.backgroundGlass;
          border.width: 1;
          border.color: CurrentTheme.border;

          Text {
            id: chipText;
            anchors.centerIn: parent;
            text: modelData.label;
            color: CurrentTheme.subtext;
            font.pixelSize: 10;
            font.weight: Font.DemiBold;
          }
          HoverHandler { cursorShape: Qt.PointingHandCursor; }
          TapHandler {
            onTapped: {
              if (modelData.act === "stop") root.svc.cancel();
              else root.svc.newChat();
              input.forceActiveFocus();
            }
          }
        }
      }
    }
  }

  // --- one message ---
  Component {
    id: rowDelegate;
    Item {
      id: row;
      required property var modelData;
      readonly property bool isUser: modelData.role === "user";
      readonly property string mail: isUser ? "" : root.emailOf(modelData.text);

      width: list.width;
      height: bubble.height;

      Rectangle {
        id: bubble;
        anchors.right: row.isUser ? parent.right : undefined;
        anchors.left: row.isUser ? undefined : parent.left;
        width: row.isUser ? parent.width * 0.85 : parent.width;
        height: content.implicitHeight + 20;
        radius: 12;
        color: row.isUser ? CurrentTheme.accent : CurrentTheme.backgroundGlass;
        border.width: row.isUser ? 0 : 1;
        border.color: CurrentTheme.border;

        Column {
          id: content;
          x: 12;
          y: 10;
          width: bubble.width - 24;
          spacing: 8;

          TextEdit {
            width: parent.width;
            readOnly: true;
            selectByMouse: true;
            textFormat: row.isUser ? TextEdit.PlainText : TextEdit.MarkdownText;
            wrapMode: TextEdit.Wrap;
            text: row.isUser ? modelData.text : root.displayOf(modelData.text);
            color: row.isUser ? CurrentTheme.background : CurrentTheme.text;
            font.pixelSize: 13;
            selectionColor: row.isUser ? CurrentTheme.background : CurrentTheme.accent;
            selectedTextColor: row.isUser ? CurrentTheme.accent : CurrentTheme.background;
            visible: text !== "";
            onLinkActivated: (link) => Qt.openUrlExternally(link);
          }

          Text {
            visible: !row.isUser && !!modelData.streaming && (modelData.text || "") === "";
            text: "Thinking…";
            color: CurrentTheme.subtext;
            font.pixelSize: 12;
            font.italic: true;
          }

          // Only offered once the whole reply has arrived.
          Rectangle {
            visible: row.mail !== "" && !modelData.streaming;
            width: parent.width;
            height: mailCol.implicitHeight + 16;
            radius: 9;
            color: CurrentTheme.surfaceHover;

            ColumnLayout {
              id: mailCol;
              anchors.fill: parent;
              anchors.margins: 8;
              spacing: 4;

              RowLayout {
                Layout.fillWidth: true;
                spacing: 8;

                Text {
                  Layout.fillWidth: true;
                  text: "Send this plan to your inbox";
                  color: CurrentTheme.text;
                  font.pixelSize: 12;
                  elide: Text.ElideRight;
                }

                Rectangle {
                  implicitHeight: 26;
                  implicitWidth: mailLabel.implicitWidth + 24;
                  radius: 13;
                  opacity: root.svc.mailStatus === "sending" ? 0.6 : 1;
                  color: root.svc.mailStatus.indexOf("error") === 0 ? CurrentTheme.danger
                    : root.svc.mailStatus === "sent" ? CurrentTheme.success : CurrentTheme.accent;

                  Text {
                    id: mailLabel;
                    anchors.centerIn: parent;
                    text: root.svc.mailStatus === "sending" ? "Sending…"
                      : root.svc.mailStatus === "sent" ? "Sent"
                      : root.svc.mailStatus.indexOf("error") === 0 ? "Retry" : "Send";
                    color: CurrentTheme.background;
                    font.pixelSize: 11;
                    font.weight: Font.DemiBold;
                  }
                  HoverHandler { cursorShape: Qt.PointingHandCursor; }
                  TapHandler { onTapped: root.svc.sendEmail(row.mail); }
                }
              }

              Text {
                Layout.fillWidth: true;
                visible: root.svc.mailStatus.indexOf("error") === 0;
                text: root.svc.mailStatus;
                color: CurrentTheme.danger;
                font.pixelSize: 10;
                wrapMode: Text.Wrap;
              }
            }
          }
        }
      }
    }
  }
}
