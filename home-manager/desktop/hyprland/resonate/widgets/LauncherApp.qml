import QtQuick
import QtQuick.Layouts
import Quickshell

import qs
import qs.services as Services

// The SUPER launcher, rendered as a ControlPanel page (openApp === "launcher")
// so it morphs the centre notch like every other app. State/logic lives in
// services/LauncherService.qml; this is search field + keyboard + lists.
Item {
  id: root;

  readonly property int appWidth: 600;
  implicitWidth: appWidth;
  implicitHeight: 456;

  readonly property var svc: Services.LauncherService;

  Component.onCompleted: Qt.callLater(() => search.forceActiveFocus());
  Connections {
    target: root.svc;
    function onOpenChanged() {
      if (root.svc.open) Qt.callLater(() => search.forceActiveFocus());
    }
    function onOpenWithPathChanged() { search.text = ""; }
  }

  function handleKey(e) {
    switch (e.key) {
    case Qt.Key_Down:    root.svc.move(1);  e.accepted = true; break;
    case Qt.Key_Up:      root.svc.move(-1); e.accepted = true; break;
    case Qt.Key_Tab:
    case Qt.Key_Backtab: root.svc.switchSection(); e.accepted = true; break;
    case Qt.Key_Return:
    case Qt.Key_Enter:   root.svc.activate(!!(e.modifiers & Qt.ShiftModifier)); e.accepted = true; break;
    case Qt.Key_Escape:  root.svc.back(); e.accepted = true; break;
    default: e.accepted = false;
    }
  }

  ColumnLayout {
    anchors.fill: parent;
    spacing: Theme.defaultSpacing;

    // --- search field ---
    Rectangle {
      Layout.fillWidth: true;
      implicitHeight: 40;
      radius: 10;
      color: CurrentTheme.backgroundGlass;
      border.width: 1;
      border.color: CurrentTheme.accent;

      RowLayout {
        anchors.fill: parent;
        anchors.leftMargin: 12;
        anchors.rightMargin: 12;
        spacing: 8;

        Text {
          text: String.fromCodePoint(root.svc.openWithPath !== "" ? 0xf0770 : 0xf0349);
          font.family: Theme.iconFontFamily;
          font.pixelSize: Theme.iconSize;
          color: CurrentTheme.subtext;
        }

        TextInput {
          id: search;
          Layout.fillWidth: true;
          verticalAlignment: TextInput.AlignVCenter;
          color: CurrentTheme.text;
          font.pixelSize: 14;
          clip: true;
          focus: true;
          Keys.priority: Keys.BeforeItem;
          Keys.onPressed: (e) => root.handleKey(e);
          onTextChanged: if (text !== root.svc.query) root.svc.query = text;

          Text {
            anchors.verticalCenter: parent.verticalCenter;
            visible: search.text === "";
            text: root.svc.openWithPath !== "" ? "Open with…"
              : root.svc.browseDir !== "" ? "Filter this folder…"
              : root.svc.section === "docs" ? "Search Documents…" : "Search apps…";
            color: CurrentTheme.subtext;
            font: search.font;
          }
        }

        Text {
          visible: root.svc.openWithPath !== "";
          text: {
            var p = root.svc.openWithPath;
            return p.slice(p.lastIndexOf("/") + 1);
          }
          color: CurrentTheme.subtext;
          font.pixelSize: 11;
          elide: Text.ElideLeft;
          Layout.maximumWidth: 200;
        }
      }
    }

    // --- section tabs (hidden in open-with mode) ---
    RowLayout {
      Layout.fillWidth: true;
      visible: root.svc.openWithPath === "";
      spacing: 6;

      Repeater {
        model: [{ key: "apps", label: "Apps" }, { key: "docs", label: "Documents" }];
        delegate: Rectangle {
          required property var modelData;
          readonly property bool active: root.svc.section === modelData.key;
          implicitHeight: 26;
          implicitWidth: tabText.implicitWidth + 22;
          radius: 13;
          color: active ? CurrentTheme.accent : CurrentTheme.backgroundGlass;
          border.width: active ? 0 : 1;
          border.color: CurrentTheme.border;
          Behavior on color { ColorAnimation { duration: 100 } }

          Text {
            id: tabText;
            anchors.centerIn: parent;
            text: modelData.label;
            font.pixelSize: 11;
            font.weight: Font.DemiBold;
            color: parent.active ? CurrentTheme.background : CurrentTheme.subtext;
          }
          HoverHandler { cursorShape: Qt.PointingHandCursor; }
          TapHandler {
            onTapped: { root.svc.section = modelData.key; search.forceActiveFocus(); }
          }
        }
      }

      Item { Layout.fillWidth: true; }

      Text {
        text: (root.svc.section === "apps" ? root.svc.apps.length : root.svc.docs.length) + "";
        color: CurrentTheme.subtext;
        font.pixelSize: 10;
      }
    }

    // --- breadcrumb while browsing a folder ---
    RowLayout {
      Layout.fillWidth: true;
      visible: root.svc.openWithPath === "" && root.svc.browseDir !== "";
      spacing: 6;

      Text {
        text: String.fromCodePoint(0xf0256); // folder-open
        font.family: Theme.iconFontFamily;
        font.pixelSize: 13;
        color: CurrentTheme.subtext;
      }
      Text {
        Layout.fillWidth: true;
        text: root.svc.browseDir.replace(Quickshell.env("HOME") || "", "~");
        color: CurrentTheme.subtext;
        font.pixelSize: 11;
        elide: Text.ElideLeft;
      }
      Text {
        text: "Esc: up";
        color: CurrentTheme.subtext;
        font.pixelSize: 10;
      }
    }

    // --- results ---
    Item {
      Layout.fillWidth: true;
      Layout.fillHeight: true;

      LauncherList {
        anchors.fill: parent;
        visible: root.svc.openWithPath === "" && root.svc.section === "apps";
        currentIndex: root.svc.appSel;
        emptyText: root.svc.query === "" ? "" : "No apps match";
        delegate: appDelegate;
        model: root.svc.apps;
      }

      LauncherList {
        anchors.fill: parent;
        visible: root.svc.openWithPath === "" && root.svc.section === "docs";
        currentIndex: root.svc.docSel;
        emptyText: root.svc.browseDir !== ""
          ? (root.svc.query === "" ? "Empty folder" : "Nothing here matches")
          : (root.svc.query === "" ? "Recent folders in Documents appear here"
             : "Nothing in Documents matches");
        delegate: docDelegate;
        model: root.svc.docs;
      }

      LauncherList {
        anchors.fill: parent;
        visible: root.svc.openWithPath !== "";
        currentIndex: root.svc.openWithSel;
        emptyText: "";
        delegate: openWithDelegate;
        model: root.svc.openWithApps;
      }
    }
  }

  // --- delegates ---

  Component {
    id: appDelegate;
    LauncherRow {
      required property var modelData;
      required property int index;
      selected: ListView.isCurrentItem;
      iconSource: modelData && modelData.icon ? Quickshell.iconPath(modelData.icon) : "";
      title: modelData ? modelData.name : "";
      subtitle: modelData ? (modelData.genericName || modelData.comment || "") : "";
      onTriggered: { root.svc.appSel = index; root.svc.activate(); }
    }
  }

  Component {
    id: docDelegate;
    LauncherRow {
      required property var modelData;
      required property int index;
      readonly property bool isUp: !!(modelData && modelData.isUp);
      selected: ListView.isCurrentItem;
      glyph: isUp ? 0xf005d /* arrow-up-thin */
        : modelData && modelData.isDir ? 0xf0256 : 0xf0214;
      title: modelData ? modelData.name : "";
      subtitle: (modelData && !isUp) ? modelData.dir : "";
      // Folders get the ">" (browse in); a tap on the body opens-with. Files
      // and ".." have no chevron and the body tap does the natural thing.
      hasChevron: !!(modelData && modelData.isDir && !isUp);
      onChevronTapped: { root.svc.docSel = index; root.svc.enterDir(modelData.path); }
      onTriggered: {
        root.svc.docSel = index;
        if (isUp) root.svc.upDir();
        else root.svc.openWithAt(index);
      }
    }
  }

  Component {
    id: openWithDelegate;
    LauncherRow {
      required property var modelData;
      required property int index;
      selected: ListView.isCurrentItem;
      glyph: modelData && modelData.isDefault ? 0xf0770 : 0;
      iconSource: modelData && modelData.entry && modelData.entry.icon
        ? Quickshell.iconPath(modelData.entry.icon) : "";
      title: modelData ? modelData.label : "";
      onTriggered: { root.svc.openWithSel = index; root.svc.activate(); }
    }
  }
}
