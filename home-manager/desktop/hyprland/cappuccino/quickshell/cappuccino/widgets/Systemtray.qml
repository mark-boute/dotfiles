import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick.Layouts
import QtQuick

import qs
import qs.shapes as S
import qs.components.menu as Menu

S.MenuDropdownPill {
  id: systemtrayWidget;

  required property QsWindow trayPopupAnchor;
  property Item currentOpenMenuItem: null;

  implicitWidth: tray.implicitWidth == 0 ? 0 
    : tray.implicitWidth + Theme.defaultMargin * 2;

  Menu.MenuView {
    id: rightclickMenu;

    menuHandle: currentOpenMenuItem ? currentOpenMenuItem.modelData.menu : null;

    onClosed: {
      currentOpenMenuItem.toggleMenu(true);
    }

    x: 0;
    y: Theme.barHeight;
  }

  menuContent: RowLayout {
    id: tray;

    spacing: Theme.defaultSpacing;

    Repeater {
      model: SystemTray.items;

      Item {
        id: trayItem;
        required property var modelData;

        property bool itemMenuOpen: false;

        height: Theme.barHeight - Theme.defaultSpacing * 2;
        width: this.height;

        IconImage {
          anchors {
            fill: this.parent;
            centerIn: this.parent;
          }

          source: {
            if (modelData.icon.includes("?path=")) {
              const [name, path] = modelData.icon.split("?path=");
              return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
            }
            return modelData.icon;
          }
        }

        function toggleMenu(close = false) {

          if (close || trayItem.itemMenuOpen) {
            itemMenuOpen = false;
            systemtrayWidget.currentOpenMenuItem = null;
            return;
          } 

          if (systemtrayWidget.menuOpen && systemtrayWidget.currentOpenMenuItem != null) {
            systemtrayWidget.currentOpenMenuItem.itemMenuOpen = false;
          }

          itemMenuOpen = true;
          systemtrayWidget.currentOpenMenuItem = trayItem;
          rightclickMenu.open();
        }

        MouseArea {
          id: mouseArea
          anchors.fill: this.parent;
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton;
          onClicked: (mouse) => {
            switch (mouse.button) {
              case Qt.LeftButton:
                modelData.activate();
                break;
              case Qt.RightButton:
                toggleMenu();
                break;
              case Qt.MiddleButton:
                modelData.secondaryActivate();
                break;
            }
          }
        }

      }
    }
  }
}