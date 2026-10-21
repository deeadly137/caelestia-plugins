pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Plugins

// Loads the page-extension entry points whose `properties.page` matches `page`. Extensions are
// plain QML items and are laid out as part of the host page, so they can add sections and controls
// that look native to that page.
ColumnLayout {
    id: root

    property string page

    readonly property var extensions: {
        const entries = Array.from(Plugins.entryPoints(EntryPointType.PageExtension));
        return entries
            .filter(entry => (entry.properties.page ?? "") === root.page)
            .sort((a, b) => (a.properties.order ?? 0) - (b.properties.order ?? 0));
    }

    visible: extensions.length > 0
    spacing: Tokens.spacing.extraSmall / 2

    Repeater {
        model: root.extensions

        delegate: EntryPointLoader {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            entryPoint: modelData
        }
    }
}
