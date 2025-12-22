import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import qs

Menu{ 
  id: menuView;
  popupType: Popup.Window;
  property alias menuHandle: menuOpener.menu;

  signal submenuExpanded(item: var)
  
  background: Rectangle {
    // anchors.fill: parent;
    border.color: Theme.current.base;
    border.width: 1;
    radius: Theme.barHeight / 2;
    color: Theme.current.surface1;
  }

  implicitWidth: Math.max(1, systrayMenu.implicitWidth);

  ColumnLayout {
    id: systrayMenu;
      
    QsMenuOpener {
      id: menuOpener;
    }

    spacing: 0;

    Repeater {
      id: menuItemsRepeater;
      model: menuOpener.children;

      Loader {
        id: menuItemLoader;
        required property var modelData
        required property int index

        property var item: Component {
          BoundComponent {
            id: itemComponent;
            source: "MenuItem.qml";
            property var entry: modelData

            property bool first: menuItemLoader.index === 0;
            property bool last: menuItemLoader.index === menuItemsRepeater.count - 1;

            function onExpandedChanged() {
              if (item.expanded) menuView.submenuExpanded(item);
            }

            function onClose() {
              menuView.close();
            }

            Connections {
              target: menuView;

              function onSubmenuExpanded(expandedItem) {
                if (item != expandedItem) item.expanded = false;
              }
            }
          }
        }

        property var separator: Component {
          Rectangle {
            color: Theme.current.base;
            implicitHeight: 1;
          }
        }

        sourceComponent: modelData.isSeparator ? separator : item;
        Layout.fillHeight: true;
        Layout.fillWidth: true;
      }
    }


  }
}
