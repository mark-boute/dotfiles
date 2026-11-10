import QtQuick

import qs
import qs.services as Services

// The checklist module: a flat list of group / table headers (tap to
// collapse), with the full ChecklistTable rendered inline under each expanded
// table. Sizes to whatever width it's given.
//
// The flat model is structural only — checked state and progress are read live
// by the delegates against ChecklistService.checkRev, so ticking a box never
// rebuilds the list.
Column {
  id: root;

  property int panelW: 300;
  width: panelW;
  spacing: 2;

  // Width this app asks the panel for (see ControlPanel.appWidth) — wide, so
  // multi-column tables have room; capped to 3/4 screen by the panel.
  readonly property int appWidth: 900;

  Component.onCompleted: Services.ChecklistService.reload();

  readonly property var svc: Services.ChecklistService;
  readonly property var entries: svc.flatten(svc.revision, svc.uiRevision);

  Text {
    width: parent.width;
    visible: text !== "";
    text: {
      if (!root.svc.configured) return "Checklist access isn't configured.";
      if (root.svc.error !== "") return root.svc.error;
      if (root.svc.loading && root.entries.length === 0) return "Loading…";
      if (root.entries.length === 0) return "No lists yet.";
      return "";
    }
    color: root.svc.error !== "" ? CurrentTheme.danger : CurrentTheme.subtext;
    font.pixelSize: 11;
    wrapMode: Text.WordWrap;
    bottomPadding: 4;
  }

  Repeater {
    model: root.entries;

    delegate: Item {
      id: d;
      required property var modelData;
      readonly property bool isGrid: modelData.kind === "grid";

      width: root.width;
      implicitHeight: isGrid ? gridLoader.implicitHeight : 26;
      height: implicitHeight;

      // --- group / table header ---
      Rectangle {
        id: headerRow;
        visible: !d.isGrid;
        anchors.fill: parent;
        radius: 5;
        color: hover.hovered ? CurrentTheme.surfaceHover : "transparent";

        readonly property bool isGroup: d.modelData.kind === "group";
        readonly property var node: root.svc.nodeById(d.modelData.id);
        readonly property var counts: root.svc.nodeCounts(node, root.svc.checkRev);

        Text {
          id: glyph;
          anchors.left: parent.left;
          anchors.leftMargin: d.modelData.depth * 14 + 4;
          anchors.verticalCenter: parent.verticalCenter;
          font.family: Theme.iconFontFamily;
          font.pixelSize: 11;
          text: headerRow.isGroup ? String.fromCodePoint(0xf07b) : String.fromCodePoint(0xf03a);
          color: CurrentTheme.subtext;
        }

        Text {
          id: chevron;
          anchors.right: parent.right;
          anchors.rightMargin: 4;
          anchors.verticalCenter: parent.verticalCenter;
          text: d.modelData.expanded ? String.fromCodePoint(0xf107) : String.fromCodePoint(0xf105);
          font.family: Theme.iconFontFamily;
          font.pixelSize: 11;
          color: CurrentTheme.subtext;
        }

        Text {
          id: prog;
          visible: headerRow.counts.total > 0;
          anchors.right: chevron.left;
          anchors.rightMargin: 6;
          anchors.verticalCenter: parent.verticalCenter;
          text: headerRow.counts.done + "/" + headerRow.counts.total;
          color: headerRow.counts.done === headerRow.counts.total
                 ? CurrentTheme.success : CurrentTheme.subtext;
          font.pixelSize: 10;
          font.weight: Font.DemiBold;
        }

        Text {
          anchors.left: glyph.right;
          anchors.leftMargin: 6;
          anchors.right: prog.visible ? prog.left : chevron.left;
          anchors.rightMargin: 6;
          anchors.verticalCenter: parent.verticalCenter;
          text: d.modelData.name;
          color: CurrentTheme.text;
          font.pixelSize: 12;
          font.weight: headerRow.isGroup ? Font.DemiBold : Font.Normal;
          elide: Text.ElideRight;
        }

        HoverHandler { id: hover; }
        TapHandler { onTapped: root.svc.toggleExpanded(d.modelData.id, d.modelData.depth === 0); }
      }

      // --- expanded table ---
      Loader {
        id: gridLoader;
        visible: d.isGrid;
        active: d.isGrid;
        width: parent.width;
        sourceComponent: tableComp;
      }

      Component {
        id: tableComp;
        ChecklistTable {
          tableId: d.modelData.tableId;
          indent: d.modelData.depth * 14;
        }
      }
    }
  }
}
