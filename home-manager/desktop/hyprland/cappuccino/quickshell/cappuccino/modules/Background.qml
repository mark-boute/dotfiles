import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

import qs

PanelWindow {
    property var modelData
    screen: modelData

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    // set color to bg color
    color: Theme.backgroundColor;
    anchors {
        top: true
        left: true
        bottom: true
        right: true
    }
    
    Image {
        id: bg
        // define fill in percentages of cover
        anchors.centerIn: parent
        width: Math.max(parent.width / 4, parent.height / 2)
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        fillMode: Image.PreserveAspectFit
        source: "/home/mark/dotfiles/home-manager/desktop/hyprland/cappuccino/assets/coffee_pixel.png"
        smooth: false
    }
}
