import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

import qs
import qs.services as Services

// Opened by the chevron handle on the workspaces island. Every workspace is
// shown as a miniature window-map — each window drawn as a box scaled from its
// real geometry (HyprlandToplevel.lastIpcObject `at`/`size`), with its app
// icon — grouped under the monitor it currently lives on.
//
// Tiles are draggable:
//   drop a tile on another tile     -> swap the two workspaces' contents
//                                      (WorkspacesService.swapContents)
//   drop a tile on another monitor  -> move that whole workspace to the
//     group's empty space              monitor (WorkspacesService.moveToMonitor)
//
// Hyprland renders workspaces sorted by id with no notion of order, so a
// same-group drag can't renumber — it swaps what's *on* the workspaces
// instead. See WorkspacesService.qml.
Item {
  id: panel;

  // Raised by the up-chevron in the header; ResizeBox wires it to
  // panelOpen = false.
  signal closeRequested();

  // This bar's HyprlandMonitor, pushed in by ResizeBox — the header shows
  // the exact same bullets the collapsed box does for this screen.
  property var monitor: null;

  readonly property bool onScreen: panel.visible && panel.width > 0;

  // Pull fresh workspace / window / monitor state every time the panel opens
  // — Hyprland doesn't push a geometry event for a re-tile, so a window's
  // cached `lastIpcObject` (which positions its box in the layout) can be
  // stale from the last time that workspace was focused.
  onOnScreenChanged: if (onScreen) {
    Hyprland.refreshMonitors();
    Hyprland.refreshWorkspaces();
    Hyprland.refreshToplevels();
  }

  readonly property int contentWidth: 340;

  // Header geometry, matched pixel-for-pixel to the collapsed box
  // (Workspaces.qml) so the chevron and bullets don't shift when the panel
  // opens over the top of it.
  readonly property real headerDotSize: Theme.barHeight - Theme.defaultSpacing * 2;
  readonly property real headerChevronWidth: headerDotSize + 4;
  readonly property real headerDotsX: Theme.defaultSpacing / 2 + headerChevronWidth + Theme.defaultSpacing / 2;

  implicitWidth: contentWidth + Theme.defaultMargin * 2;
  implicitHeight: Theme.barHeight + Theme.defaultSpacing / 2
    + Math.min(column.implicitHeight,
               Theme.maxPanelHeight - Theme.barHeight - Theme.defaultSpacing / 2 - Theme.defaultMargin)
    + Theme.defaultMargin;

  // --- drag state ----------------------------------------------------
  property int dragWsId: -1;
  property int dragSrcMonId: -1;
  property point dragScenePos: Qt.point(0, 0);
  readonly property bool dragging: dragWsId >= 0;

  // Delegates register their own item here; ids/monitors are read live off
  // the item at drop time (a swap changes workspace ids underneath us).
  property var chipTargets: [];   // [chip Item], each has .ws and .monId
  property var monTargets: [];    // [section Item], each has .mon

  function _hit(list, scenePos) {
    // Last match wins → innermost/topmost, since tiles register after their
    // section. Good enough; tiles never overlap.
    var found = null;
    for (var i = 0; i < list.length; i++) {
      var it = list[i];
      if (!it || !it.visible) continue;
      var lp = it.mapFromItem(null, scenePos.x, scenePos.y);
      if (lp.x >= 0 && lp.y >= 0 && lp.x <= it.width && lp.y <= it.height) found = it;
    }
    return found;
  }

  function endDrag(commit) {
    if (panel.dragWsId >= 0 && commit) {
      var chip = _hit(panel.chipTargets, panel.dragScenePos);
      if (chip && chip.wsId !== panel.dragWsId) {
        Services.WorkspacesService.swapContents(panel.dragWsId, chip.wsId);
      } else if (!chip) {
        var section = _hit(panel.monTargets, panel.dragScenePos);
        if (section && section.mon.id !== panel.dragSrcMonId) {
          Services.WorkspacesService.moveToMonitor(panel.dragWsId, section.mon.name);
        }
      }
    }
    panel.dragWsId = -1;
    panel.dragSrcMonId = -1;
  }

  // Just the content now — the painted surface (fill + shadow + the outward
  // curve into the connecting strip) is BarSurface, one shared shape drawn
  // once for the whole bar in Bar.qml.
  Item {
    anchors.fill: parent;

    // Header — an up-chevron (closes the panel) then the same bullet row the
    // collapsed box shows. Positioned to sit exactly where the box's own
    // chevron + bullets are (see panel.header* geometry above), so the
    // bullets don't jump when the panel opens over the box.
    Item {
      id: header;
      anchors { left: parent.left; right: parent.right; top: parent.top; }
      height: Theme.barHeight;

      Item {
        id: closeChevron;
        x: Theme.defaultSpacing / 2;
        width: panel.headerChevronWidth;
        height: parent.height;

        Text {
          anchors.centerIn: parent;
          text: String.fromCodePoint(0xf0143); // md-chevron_up
          font.family: Theme.iconFontFamily;
          font.pixelSize: Theme.iconSize;
          color: closeHover.hovered ? CurrentTheme.text : CurrentTheme.subtext;
        }

        HoverHandler { id: closeHover; }
        TapHandler { onTapped: panel.closeRequested(); }
      }

      WorkspaceDots {
        x: panel.headerDotsX;
        anchors.verticalCenter: parent.verticalCenter;
        dotSize: panel.headerDotSize;
        monitor: panel.monitor;
      }
    }

    Column {
      id: column;
      anchors {
        left: parent.left;
        right: parent.right;
        top: header.bottom;
        leftMargin: Theme.defaultMargin;
        rightMargin: Theme.defaultMargin;
        topMargin: Theme.defaultSpacing / 2;
      }
      spacing: Theme.defaultSpacing;

      Repeater {
        model: Hyprland.monitors;

        // --- one monitor group ---
        Rectangle {
          id: section;
          required property var modelData;
          readonly property var mon: modelData;

          width: column.width;
          implicitHeight: sectionCol.implicitHeight + Theme.defaultSpacing * 2;
          radius: 12;
          color: panel.dragging && dropHover && panel.dragSrcMonId !== mon.id
            ? CurrentTheme.surfaceHover : CurrentTheme.backgroundGlass;

          Behavior on color { ColorAnimation { duration: 120 } }

          property bool dropHover: false;

          // Tiles carry the monitor's real aspect ratio. Normal screens go
          // two per row; an ultrawide (>2:1) gets a single full-width tile so
          // its preview doesn't collapse to a letterbox sliver. Portrait /
          // very tall tiles are capped so one screen can't blow the height
          // budget.
          readonly property real aspect: (mon.width > 0 && mon.height > 0) ? mon.width / mon.height : 1.6;
          readonly property int cols: aspect > 2.1 ? 1 : 2;
          readonly property real tileW: (sectionCol.width - 6 * (cols - 1)) / cols;
          readonly property real tileH: Math.min(tileW / aspect, 220);

          // The Repeater is keyed on the sorted workspace *ids* on this
          // monitor, not the workspace objects — a reorder (change_id) keeps
          // the same ids, so each tile just re-resolves its workspace from its
          // id (`chip.ws` below) and its window list follows. Rebuilt
          // imperatively (reading Hyprland.workspaces.values inside a binding
          // trips a false binding-loop warning) and only reassigned when the
          // id set actually changes, so the Repeater doesn't thrash.
          property var wsIds: [];
          function rebuildWsIds() {
            var ids = [];
            var vals = Hyprland.workspaces.values;
            for (var i = 0; i < vals.length; i++) {
              var w = vals[i];
              if (w && w.id > 0 && w.monitor && w.monitor.id === mon.id) ids.push(w.id);
            }
            ids.sort((a, b) => a - b);
            if (ids.length !== wsIds.length || ids.some((v, i) => v !== wsIds[i])) wsIds = ids;
          }
          Connections {
            target: Hyprland.workspaces;
            function onValuesChanged() { section.rebuildWsIds(); }
          }
          Connections {
            target: Services.WorkspacesService;
            function onReorderTickChanged() { section.rebuildWsIds(); }
          }

          Component.onCompleted: { rebuildWsIds(); panel.monTargets.push(section); }
          Component.onDestruction: {
            panel.monTargets = panel.monTargets.filter((t) => t !== section);
          }

          Connections {
            target: panel;
            function onDragScenePosChanged() {
              if (!panel.dragging) { section.dropHover = false; return; }
              var lp = section.mapFromItem(null, panel.dragScenePos.x, panel.dragScenePos.y);
              section.dropHover = lp.x >= 0 && lp.y >= 0 && lp.x <= section.width && lp.y <= section.height;
            }
            function onDraggingChanged() { if (!panel.dragging) section.dropHover = false; }
          }

          Column {
            id: sectionCol;
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.defaultSpacing; }
            spacing: 6;

            Item {
              width: parent.width;
              height: 28;

              Row {
                anchors.verticalCenter: parent.verticalCenter;
                spacing: 8;
                Text {
                  anchors.verticalCenter: parent.verticalCenter;
                  text: section.mon.name;
                  color: CurrentTheme.text;
                  font.pixelSize: 12;
                  font.weight: Font.Bold;
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter;
                  text: section.mon.width + "×" + section.mon.height;
                  color: CurrentTheme.subtext;
                  font.pixelSize: 11;
                }
              }

              // Refresh rates this monitor offers at its current resolution.
              Rectangle {
                id: hzSwitch;
                readonly property var io: section.mon.lastIpcObject || ({});
                readonly property var rates: {
                  var prefix = io.width + "x" + io.height + "@";
                  var seen = [];
                  (io.availableModes || []).forEach(function (m) {
                    if (m.indexOf(prefix) !== 0) return;
                    var hz = Math.round(parseFloat(m.slice(prefix.length)));
                    if (hz > 0 && seen.indexOf(hz) < 0) seen.push(hz);
                  });
                  return seen.sort((a, b) => b - a);
                }
                readonly property int current: Math.round(io.refreshRate || 0);

                visible: rates.length > 1;
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; }
                width: hzRow.implicitWidth + 4;
                height: 28;
                radius: 14;
                color: Qt.rgba(Theme.palette.base.r, Theme.palette.base.g, Theme.palette.base.b, 0.72);
                border.width: 1;
                border.color: CurrentTheme.border;

                Row {
                  id: hzRow;
                  anchors.centerIn: parent;
                  spacing: 2;
                  Repeater {
                    model: hzSwitch.rates;
                    Rectangle {
                      id: hzChip;
                      required property int modelData;
                      readonly property bool on: hzSwitch.current === modelData;
                      width: hzLabel.implicitWidth + 20;
                      height: 22;
                      radius: 11;
                      color: on ? CurrentTheme.fill : "transparent";
                      Behavior on color { ColorAnimation { duration: 180 } }
                      Text {
                        id: hzLabel;
                        anchors.centerIn: parent;
                        text: hzChip.modelData + " Hz";
                        color: hzChip.on ? CurrentTheme.onFill : CurrentTheme.text;
                        font.pixelSize: 11; font.weight: Font.Bold;
                        Behavior on color { ColorAnimation { duration: 180 } }
                      }
                      HoverHandler { cursorShape: Qt.PointingHandCursor; }
                      TapHandler {
                        onTapped: if (!hzChip.on) Services.WorkspacesService.setRefreshRate(section.mon, hzChip.modelData);
                      }
                    }
                  }
                }
              }
            }

            Flow {
              width: parent.width;
              spacing: 6;

              Repeater {
                model: section.wsIds;

                // --- one workspace preview tile ---
                Rectangle {
                  id: chip;
                  required property int modelData;   // the workspace id
                  readonly property int wsId: modelData;
                  readonly property int monId: section.mon.id;

                  // Re-resolved after a reorder → this tile now points at
                  // whatever workspace carries its number.
                  readonly property var ws: {
                    void Services.WorkspacesService.reorderTick;
                    var vals = Hyprland.workspaces.values;
                    for (var i = 0; i < vals.length; i++)
                      if (vals[i] && vals[i].id === chip.wsId) return vals[i];
                    return null;
                  }

                  // Windows on this workspace — filtered from the global
                  // toplevel list by workspace id rather than trusting
                  // HyprlandWorkspace.toplevels, which comes back over-full
                  // (stale associations) after a change_id shuffle. Imperative
                  // for the same reason as wsIds above.
                  property var wins: [];
                  function rebuildWins() {
                    var out = [];
                    var all = Hyprland.toplevels.values;
                    for (var i = 0; i < all.length; i++) {
                      var t = all[i];
                      if (t && t.workspace && t.workspace.id === chip.wsId) out.push(t);
                    }
                    if (out.length !== wins.length || out.some((t, i) => t !== wins[i])) wins = out;
                  }
                  onWsIdChanged: rebuildWins();
                  Connections {
                    target: Hyprland.toplevels;
                    function onValuesChanged() { chip.rebuildWins(); }
                  }
                  Connections {
                    target: Services.WorkspacesService;
                    function onReorderTickChanged() { chip.rebuildWins(); }
                  }

                  width: section.tileW;
                  height: section.tileH;
                  radius: 8;
                  clip: true;

                  readonly property bool wsActive: chip.ws && chip.ws.active;
                  readonly property bool beingDragged: panel.dragWsId === chip.wsId;
                  readonly property bool swapTarget: panel.dragging && !beingDragged && chipHover;
                  property bool chipHover: false;

                  color: CurrentTheme.backgroundGlass;
                  opacity: beingDragged ? 0.35 : 1;
                  border.width: swapTarget || wsActive ? 2 : 1;
                  border.color: swapTarget ? CurrentTheme.accent
                    : wsActive ? CurrentTheme.accent
                    : CurrentTheme.border;

                  Behavior on opacity { NumberAnimation { duration: 120 } }
                  Behavior on border.color { ColorAnimation { duration: 120 } }

                  Component.onCompleted: { rebuildWins(); panel.chipTargets.push(chip); }
                  Component.onDestruction: {
                    panel.chipTargets = panel.chipTargets.filter((t) => t !== chip);
                  }

                  Connections {
                    target: panel;
                    function onDragScenePosChanged() {
                      if (!panel.dragging || chip.beingDragged) { chip.chipHover = false; return; }
                      var lp = chip.mapFromItem(null, panel.dragScenePos.x, panel.dragScenePos.y);
                      chip.chipHover = lp.x >= 0 && lp.y >= 0 && lp.x <= chip.width && lp.y <= chip.height;
                    }
                    function onDraggingChanged() { if (!panel.dragging) chip.chipHover = false; }
                  }

                  // --- window map ---
                  Item {
                    id: preview;
                    anchors.fill: parent;

                    // Window `at`/`size` from Hyprland are in *logical* pixels,
                    // but HyprlandMonitor.width/height are *physical* — so the
                    // usable area is the monitor divided by its scale.
                    // Without this a maximised window looked inset by the
                    // scale factor on the right and bottom.
                    readonly property real monScale: section.mon.scale > 0 ? section.mon.scale : 1;
                    readonly property real logW: section.mon.width / monScale;
                    readonly property real logH: section.mon.height / monScale;
                    readonly property real sc: logW > 0 ? width / logW : 0;

                    Repeater {
                      model: chip.wins;

                      Rectangle {
                        id: win;
                        required property var modelData;
                        readonly property var io: modelData.lastIpcObject || null;
                        readonly property bool fs: io && io.fullscreen > 0;

                        // Hidden until the monitor geometry is known, otherwise
                        // preview.sc is 0 and every window collapses to a 9px
                        // dot in the corner.
                        visible: preview.sc > 0;

                        readonly property real wx: (io && io.at ? io.at[0] : section.mon.x) - section.mon.x;
                        readonly property real wy: (io && io.at ? io.at[1] : section.mon.y) - section.mon.y;
                        readonly property real ww: io && io.size ? io.size[0] : preview.logW;
                        readonly property real wh: io && io.size ? io.size[1] : preview.logH;

                        x: fs ? 0 : Math.max(0, wx * preview.sc);
                        y: fs ? 0 : Math.max(0, wy * preview.sc);
                        width: fs ? preview.width : Math.max(9, ww * preview.sc);
                        height: fs ? preview.height : Math.max(9, wh * preview.sc);
                        radius: 2;

                        // Themed "window" fill — a solid step up from the
                        // tile's own background, accent-tinted for the focused
                        // window. Follows the Catppuccin flavor via CurrentTheme.
                        color: modelData.activated
                          ? Qt.rgba(CurrentTheme.accent.r, CurrentTheme.accent.g, CurrentTheme.accent.b, 0.22)
                          : CurrentTheme.surfaceHover;
                        border.width: 1;
                        border.color: modelData.activated ? CurrentTheme.accent : CurrentTheme.border;
                        clip: true;

                        readonly property string wclass: (io && io.class) ? io.class : (modelData.title || "");
                        readonly property var entry: DesktopEntries.heuristicLookup(win.wclass);
                        readonly property string iconSrc: {
                          var name = (win.entry && win.entry.icon) ? win.entry.icon
                            : win.wclass ? win.wclass.split(".").pop() : "";
                          return name ? Quickshell.iconPath(name) : "";
                        }

                        // The window's app icon, over its first initial as a
                        // fallback. No live thumbnail: Hyprland doesn't
                        // composite hidden workspaces so their windows can't be
                        // captured, and a live shot of the workspace you're
                        // already looking at is just redundant.
                        Text {
                          anchors.centerIn: parent;
                          visible: parent.width > 14 && parent.height > 12;
                          text: (win.wclass || "?").charAt(0).toUpperCase();
                          color: CurrentTheme.subtext;
                          font.pixelSize: 11;
                          font.weight: Font.Bold;
                        }
                        IconImage {
                          anchors.centerIn: parent;
                          implicitSize: Math.max(10, Math.min(parent.width - 6, parent.height - 6, 26));
                          visible: win.iconSrc !== "" && parent.width > 12 && parent.height > 12;
                          source: win.iconSrc;
                        }
                      }
                    }

                    Text {
                      anchors.centerIn: parent;
                      visible: chip.wins.length === 0;
                      text: "empty";
                      color: CurrentTheme.subtext;
                      font.pixelSize: 9;
                    }
                  }

                  // --- workspace id badge ---
                  Rectangle {
                    anchors { top: parent.top; left: parent.left; margins: 3; }
                    width: 16; height: 16; radius: 5;
                    color: chip.wsActive ? CurrentTheme.accent : CurrentTheme.surface;
                    border.width: 1;
                    border.color: chip.wsActive ? CurrentTheme.accent : CurrentTheme.border;

                    Text {
                      anchors.centerIn: parent;
                      text: chip.wsId;
                      color: chip.wsActive ? CurrentTheme.background : CurrentTheme.text;
                      font.pixelSize: 10;
                      font.weight: Font.Bold;
                    }
                  }

                  TapHandler {
                    onTapped: if (chip.ws) chip.ws.activate();
                  }

                  DragHandler {
                    id: chipDrag;
                    target: null;
                    dragThreshold: 6;
                    onActiveChanged: {
                      if (active) {
                        panel.dragWsId = chip.wsId;
                        panel.dragSrcMonId = section.mon.id;
                        panel.dragScenePos = centroid.scenePosition;
                      } else {
                        panel.endDrag(true);
                      }
                    }
                    onCentroidChanged: if (active) panel.dragScenePos = centroid.scenePosition;
                  }
                }
              }
            }
          }
        }
      }

      Text {
        width: column.width;
        text: "Drag a workspace onto another to swap what's on them, or onto a different monitor to move it there.";
        color: CurrentTheme.subtext;
        font.pixelSize: 10;
        wrapMode: Text.WordWrap;
      }
    }

    // --- floating ghost that follows the cursor ---
    Rectangle {
      id: ghost;
      visible: panel.dragging;
      width: 46; height: 30; radius: 8;
      color: CurrentTheme.accent;
      opacity: 0.9;
      z: 100;

      readonly property point local: panel.mapFromItem(null, panel.dragScenePos.x, panel.dragScenePos.y);
      x: local.x - width / 2;
      y: local.y - height / 2;

      Text {
        anchors.centerIn: parent;
        text: panel.dragWsId >= 0 ? panel.dragWsId : "";
        color: CurrentTheme.background;
        font.pixelSize: 13;
        font.weight: Font.Bold;
      }
    }
  }
}
