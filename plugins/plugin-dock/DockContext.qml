// Context popout for the dock: pin/unpin the app, open a new window and end its tasks. Opened by
// the dock entry under the reserved `dockcontext` name.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property SettingsObject settings
    property var popouts: null

    property var model: root.popouts?.dockModel ?? null

    readonly property bool isPinned: {
        const current = GlobalConfig.launcher.favouriteApps || [];
        if (!root.model)
            return false;
        return current.some(id => id === root.model.id || (root.model.entry && root.model.entry.id === id));
    }

    objectName: "pluginDockContext"

    width: 200
    implicitWidth: 200
    spacing: Tokens.spacing.medium

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true
        visible: root.model && root.model.entry != null

        ColumnLayout {
            id: cardLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            StyledRect {
                id: pinItem

                Layout.fillWidth: true
                implicitHeight: pinLabel.implicitHeight
                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    anchors.margins: -Tokens.padding.medium / 2
                    anchors.leftMargin: -Tokens.padding.medium
                    anchors.rightMargin: -Tokens.padding.medium
                    radius: pinItem.radius

                    onClicked: {
                        const current = GlobalConfig.launcher.favouriteApps ? [...GlobalConfig.launcher.favouriteApps] : [];
                        let index = current.indexOf(root.model.id);
                        if (index === -1 && root.model.entry)
                            index = current.indexOf(root.model.entry.id);

                        if (index !== -1) {
                            current.splice(index, 1);
                            GlobalConfig.launcher.favouriteApps = current;
                        } else {
                            const idToPin = root.model.entry ? root.model.entry.id : root.model.id;
                            if (!current.includes(idToPin)) {
                                current.push(idToPin);
                                GlobalConfig.launcher.favouriteApps = current;
                            }
                        }
                        root.popouts.hasCurrent = false;
                    }
                }

                StyledText {
                    id: pinLabel

                    anchors.left: parent.left
                    text: root.isPinned ? "Unpin from dock" : "Pin to dock"
                }
            }

            StyledRect {
                id: newWinItem

                Layout.fillWidth: true
                implicitHeight: newWinLabel.implicitHeight
                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    anchors.margins: -Tokens.padding.medium / 2
                    anchors.leftMargin: -Tokens.padding.medium
                    anchors.rightMargin: -Tokens.padding.medium
                    radius: newWinItem.radius

                    onClicked: {
                        const entry = root.model?.entry;
                        if (entry) {
                            const command = entry.runInTerminal ? [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command] : entry.command;
                            Quickshell.execDetached({
                                command: command,
                                workingDirectory: entry.workingDirectory
                            });
                        }
                        root.popouts.hasCurrent = false;
                    }
                }

                StyledText {
                    id: newWinLabel

                    anchors.left: parent.left
                    text: "Open new window"
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small
        text: "End task"
        icon: "close"
        visible: root.model && root.model.toplevels && root.model.toplevels.length > 0

        onClicked: {
            for (const toplevel of root.model.toplevels)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${toplevel.address}" })` : `closewindow address:0x${toplevel.address}`);
            root.popouts.hasCurrent = false;
        }
    }
}
