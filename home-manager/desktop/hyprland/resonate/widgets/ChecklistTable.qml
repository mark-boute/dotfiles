import QtQuick

import qs
import qs.services as Services

// The full grid for one checklist table: a header row + every data row, with a
// tick box on each. Columns are fixed-width and the whole grid scrolls
// horizontally inside its own Flickable when it's wider than the panel (the
// panel's body Flickable handles the vertical scroll). Image cells render as
// thumbnails. Checked state is read live against ChecklistService.checkRev, so
// a tick only re-styles the affected row — no rebuild.
Item {
  id: root;

  property string tableId: "";
  property int indent: 0;

  readonly property var svc: Services.ChecklistService;
  readonly property var table: tableId ? svc.nodeById(tableId) : null;
  readonly property var cols: (table && table.columns) ? table.columns : [];
  readonly property var rows: (table && table.rows) ? table.rows : [];
  readonly property int keyCol: table ? table.keyColumn : 0;

  readonly property int rowH: 30;
  readonly property int checkW: 30;
  readonly property int cellW: 132;
  readonly property int imgW: 46;

  function _isImageCol(ci) {
    if (String(cols[ci]).toLowerCase().indexOf("image") !== -1) return true;
    for (var r = 0; r < rows.length; r++) {
      var v = rows[r][ci];
      if (v !== undefined && v !== null && v !== "") return svc.imgUrl(v) !== "";
    }
    return false;
  }
  readonly property var colWidths: {
    var a = [];
    for (var i = 0; i < cols.length; i++) a.push(_isImageCol(i) ? imgW : cellW);
    return a;
  }
  readonly property real tableW: {
    var w = checkW;
    for (var i = 0; i < colWidths.length; i++) w += colWidths[i];
    return w;
  }

  implicitHeight: rows.length > 0 ? rowH * (rows.length + 1) + 6 : 0;

  Flickable {
    id: hflick;
    x: root.indent;
    width: Math.max(0, root.width - root.indent);
    height: root.implicitHeight;
    contentWidth: root.tableW;
    contentHeight: height;
    flickableDirection: Flickable.HorizontalFlick;
    interactive: contentWidth > width;
    boundsBehavior: Flickable.StopAtBounds;
    clip: true;

    Column {
      spacing: 0;

      // --- header ---
      Row {
        Rectangle {
          width: root.checkW; height: root.rowH;
          color: CurrentTheme.backgroundGlass;
          Text {
            anchors.centerIn: parent;
            text: String.fromCodePoint(0xf00c); // check
            font.family: Theme.iconFontFamily;
            font.pixelSize: 10;
            color: CurrentTheme.subtext;
          }
        }
        Repeater {
          model: root.cols;
          Rectangle {
            id: hcell;
            required property int index;
            required property string modelData;
            width: root.colWidths[index];
            height: root.rowH;
            color: CurrentTheme.backgroundGlass;
            Text {
              anchors.fill: parent;
              anchors.margins: 5;
              verticalAlignment: Text.AlignVCenter;
              text: hcell.modelData;
              color: CurrentTheme.subtext;
              font.pixelSize: 10;
              font.weight: Font.DemiBold;
              elide: Text.ElideRight;
            }
          }
        }
      }

      // --- data rows ---
      Repeater {
        model: root.rows.length;

        Row {
          id: dataRow;
          required property int index;
          readonly property bool checked: root.table
            ? root.svc.isRowChecked(root.table, index, root.svc.checkRev) : false;

          function bg(hovered) {
            if (dataRow.checked) return CurrentTheme.caughtBackground;
            if (hovered) return CurrentTheme.surfaceHover;
            return dataRow.index % 2 ? CurrentTheme.background : "transparent";
          }

          Rectangle {
            width: root.checkW;
            height: root.rowH;
            color: dataRow.bg(rowHover.hovered);
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent;
              text: dataRow.checked ? String.fromCodePoint(0xf046) : String.fromCodePoint(0xf096);
              font.family: Theme.iconFontFamily;
              font.pixelSize: 13;
              color: dataRow.checked ? CurrentTheme.success : CurrentTheme.subtext;
            }
            HoverHandler { id: rowHover; }
            TapHandler {
              onTapped: if (root.table)
                root.svc.setRowChecked(root.table.id, dataRow.index, !dataRow.checked);
            }
          }

          Repeater {
            model: root.cols.length;

            Rectangle {
              id: cell;
              required property int index;
              readonly property var value: root.rows[dataRow.index][index];
              readonly property string img: root.svc.imgUrl(cell.value);
              readonly property bool isKey: cell.index === root.keyCol;

              width: root.colWidths[index];
              height: root.rowH;
              color: dataRow.bg(false);
              Behavior on color { ColorAnimation { duration: 120 } }

              Image {
                visible: cell.img !== "";
                anchors.centerIn: parent;
                source: cell.img;
                sourceSize.height: root.rowH - 8;
                fillMode: Image.PreserveAspectFit;
                asynchronous: true;
                cache: true;
              }
              Text {
                visible: cell.img === "";
                anchors.fill: parent;
                anchors.margins: 5;
                verticalAlignment: Text.AlignVCenter;
                horizontalAlignment: (typeof cell.value === "number") ? Text.AlignRight : Text.AlignLeft;
                text: (cell.value === undefined || cell.value === null) ? "" : String(cell.value);
                color: dataRow.checked
                  ? (cell.isKey ? CurrentTheme.success : CurrentTheme.subtext)
                  : (cell.isKey ? CurrentTheme.text : CurrentTheme.subtext);
                font.pixelSize: 10;
                font.weight: cell.isKey ? Font.DemiBold : Font.Normal;
                elide: Text.ElideRight;
              }
            }
          }
        }
      }
    }
  }
}
