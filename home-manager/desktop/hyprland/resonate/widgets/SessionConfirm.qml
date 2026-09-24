import QtQuick
import QtQuick.Layouts

import qs
import qs.services as Services

// Power off / restart / hibernate / log out confirm, shown inside the power
// slot (SystemPanel morphs into it). The confirm button is preselected, so a
// shortcut then Enter goes straight through. Left/Right or Tab switch, Esc
// cancels. SessionService runs the command.
Item {
  id: root;

  property bool shown: false;
  // "confirm" | "cancel"
  property string selection: "confirm";

  readonly property var def: Services.SessionService.def;
  readonly property bool danger: !!def && def.danger;

  implicitHeight: col.implicitHeight + 40;

  function activate() {
    if (root.selection === "cancel") Services.SessionService.cancel();
    else Services.SessionService.confirm();
  }

  // The layer surface only becomes focusable a moment after it gets
  // exclusive keyboard focus, so keep trying briefly.
  function grab() { if (root.shown) keys.forceActiveFocus(); }
  onShownChanged: if (shown) { root.selection = "confirm"; grabRetry.restart(); }
  Timer {
    id: grabRetry;
    interval: 40; repeat: true; triggeredOnStart: true;
    property int left: 8;
    onTriggered: {
      root.grab();
      if (!root.shown || keys.activeFocus || --left <= 0) { left = 8; stop(); }
    }
  }

  Item {
    id: keys;
    anchors.fill: parent;
    focus: root.shown;
    Keys.priority: Keys.BeforeItem;
    Keys.onPressed: (e) => {
      switch (e.key) {
      case Qt.Key_Escape:  Services.SessionService.cancel(); break;
      case Qt.Key_Return:
      case Qt.Key_Enter:
      case Qt.Key_Space:   root.activate(); break;
      case Qt.Key_Left:
      case Qt.Key_Up:      root.selection = "cancel"; break;
      case Qt.Key_Right:
      case Qt.Key_Down:    root.selection = "confirm"; break;
      case Qt.Key_Tab:
      case Qt.Key_Backtab: root.selection = root.selection === "confirm" ? "cancel" : "confirm"; break;
      default: e.accepted = false; return;
      }
      e.accepted = true;
    }
  }

  ColumnLayout {
    id: col;
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; }
    spacing: 14;

    RowLayout {
      Layout.fillWidth: true;
      Layout.preferredHeight: 44;
      spacing: 14;

      Text {
        text: root.def ? String.fromCodePoint(root.def.glyph) : "";
        font.family: Theme.iconFontFamily;
        font.pixelSize: 26;
        color: root.danger ? CurrentTheme.danger : CurrentTheme.text;
      }
      ColumnLayout {
        Layout.fillWidth: true;
        spacing: 2;
        Text {
          text: root.def ? root.def.title + "?" : "";
          color: CurrentTheme.text;
          font.pixelSize: 18; font.weight: Font.Bold;
        }
        Text {
          Layout.fillWidth: true;
          text: Services.SessionService.pending === "hibernate"
            ? "Saves your session to disk and turns off."
            : Services.SessionService.pending === "logout"
            ? "Ends your session and closes every open app."
            : "Closes every open app on this machine.";
          color: CurrentTheme.subtext;
          font.pixelSize: 12;
          elide: Text.ElideRight;
        }
      }
    }

    // Only when the title scan found something.
    Rectangle {
      Layout.fillWidth: true;
      visible: Services.SessionService.dirty.length > 0;
      implicitHeight: dirtyCol.implicitHeight + 20;
      radius: 10;
      color: Qt.rgba(CurrentTheme.warning.r, CurrentTheme.warning.g, CurrentTheme.warning.b, 0.12);
      border.width: 1;
      border.color: Qt.rgba(CurrentTheme.warning.r, CurrentTheme.warning.g, CurrentTheme.warning.b, 0.4);

      ColumnLayout {
        id: dirtyCol;
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 12; rightMargin: 12; }
        spacing: 4;
        Text {
          text: "Possibly unsaved work";
          color: CurrentTheme.warning;
          font.pixelSize: 12; font.weight: Font.Bold;
        }
        Repeater {
          model: Services.SessionService.dirty.slice(0, 4);
          Text {
            required property var modelData;
            Layout.fillWidth: true;
            text: "<font color='" + CurrentTheme.subtext + "'>•</font> " + modelData.title;
            textFormat: Text.StyledText;
            color: CurrentTheme.text;
            font.pixelSize: 12;
            elide: Text.ElideRight;
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true;
      spacing: 10;

      Rectangle {
        Layout.fillWidth: true;
        Layout.preferredWidth: 1;
        implicitHeight: 40;
        radius: 10;
        readonly property bool sel: root.selection === "cancel";
        color: sel ? CurrentTheme.surfaceHover : "transparent";
        border.width: sel ? 2 : 1;
        border.color: sel ? CurrentTheme.accent : CurrentTheme.border;
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
          anchors.centerIn: parent;
          text: "Cancel";
          color: CurrentTheme.text;
          font.pixelSize: 13;
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.selection = "cancel"; }
        TapHandler { onTapped: Services.SessionService.cancel(); }
      }

      Rectangle {
        Layout.fillWidth: true;
        Layout.preferredWidth: 1;
        implicitHeight: 40;
        radius: 10;
        readonly property bool sel: root.selection === "confirm";
        color: root.danger
          ? Qt.rgba(CurrentTheme.danger.r, CurrentTheme.danger.g, CurrentTheme.danger.b, sel ? 0.28 : 0.18)
          : (sel ? CurrentTheme.surfaceHover : CurrentTheme.chip);
        border.width: sel ? 2 : 1;
        border.color: sel ? CurrentTheme.accent : CurrentTheme.border;
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
          anchors.centerIn: parent;
          text: root.def ? root.def.verb : "";
          color: root.danger ? CurrentTheme.danger : CurrentTheme.text;
          font.pixelSize: 13; font.weight: Font.Bold;
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.selection = "confirm"; }
        TapHandler { onTapped: Services.SessionService.confirm(); }
      }
    }
  }
}
