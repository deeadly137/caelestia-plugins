pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Plugins
import qs.components.containers
import qs.services

// A transparent layer surface below normal windows, so plugin widgets can sit on top of the
// wallpaper without covering applications. The window only exists while a desktop widget plugin
// is enabled.
Variants {
    id: root

    readonly property var widgets: Plugins.entryPoints(EntryPointType.DesktopWidget)

    model: widgets.length > 0 ? Screens.screens : []

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "desktop-widgets"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Repeater {
            model: root.widgets

            EntryPointLoader {
                required property var modelData

                anchors.fill: parent
                entryPoint: modelData
            }
        }
    }
}
