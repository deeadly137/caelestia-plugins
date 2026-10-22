pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.modules.nexus.common

// A Nexus sub-page supplied by a `page-extension` entry point that declares
// `properties.subpage`. The host page lists it as a button and opens this component by index, so
// the page survives Nexus reloads through the normal sub-page stack. `slot` picks which of the
// page's sub-page extensions to show, in the same order the buttons are built.
PageBase {
    id: root

    required property string page
    property int slot: 0

    readonly property var extensions: {
        const entries = Array.from(Plugins.entryPoints(EntryPointType.PageExtension));
        return entries
            .filter(entry => (entry.properties.page ?? "") === root.page && (entry.properties.subpage ?? "") !== "")
            .sort((a, b) => (a.properties.order ?? 0) - (b.properties.order ?? 0));
    }
    readonly property var extension: root.extensions[root.slot] ?? null

    title: root.extension?.properties?.subpageTitle ?? ""
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        EntryPointLoader {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            entryPoint: root.extension
        }
    }
}
