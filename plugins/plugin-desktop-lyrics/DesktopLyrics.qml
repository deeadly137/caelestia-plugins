pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Plugins
import deeadly137.desktoplyrics

// Entry point wrapper for the desktop-widget host. The manifest declares this file twice: once
// with `layer: bottom` and `overlay: false` for the desktop copy, once with `layer: top` and
// `overlay: true` for the above-window copy. `layer` stays host metadata; `overlay` is declared
// here so the loader injects it, and only the copy matching the setting keeps a surface alive.
Item {
    id: root

    required property SettingsObject settings

    property bool overlay: false

    readonly property var general: root.settings.general

    // Only the copy matching the Overlay lyrics setting keeps a surface alive, and the feature
    // toggle in General tears both down.
    readonly property bool active: (root.general?.enabled ?? true) && ((root.general?.overlay ?? false) === root.overlay)

    Loader {
        anchors.fill: parent
        active: root.active
        sourceComponent: lyricsComponent
    }

    Component {
        id: lyricsComponent

        DesktopLyricsSurface {
            settings: root.settings
            overlay: root.overlay
        }
    }
}
