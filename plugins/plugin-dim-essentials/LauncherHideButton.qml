// Per-app hide/show button injected into the launcher rows through the `launcher.itemActions`
// slot. The host sets `entry` and `screenState`; the plugin supplies `settings`.
pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Plugins
import qs.components
import qs.services

Item {
    id: root

    property var settings
    property var entry
    property var screenState

    readonly property var hiddenApps: Array.isArray(root.settings?.hiddenApps) ? root.settings.hiddenApps : []
    readonly property bool hidden: root.entry ? root.hiddenApps.includes(root.entry.id) : false

    implicitWidth: 32
    implicitHeight: 32

    function toggle(): void {
        if (!root.entry || !root.settings)
            return;

        const list = Array.isArray(root.settings.hiddenApps) ? [...root.settings.hiddenApps] : [];
        const index = list.indexOf(root.entry.id);
        if (index === -1)
            list.push(root.entry.id);
        else
            list.splice(index, 1);
        root.settings.hiddenApps = list;
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.hidden ? "visibility_off" : "visibility"
        color: mouse.containsMouse ? Colours.palette.m3primary : Colours.palette.m3outline
    }
}
