pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Plugins
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var plugin: {
        const list = Array.from(Plugins.plugins);
        return list.find(p => p.id === nState.selectedPluginId) ?? null;
    }
    readonly property var settings: plugin?.settings
    readonly property bool managed: plugin != null && Plugins.isManaged(plugin.id)

    property var values: ({})
    property var keys: []
    property Connections settingsConnections: Connections {
        target: root.settings

        function onChanged(): void {
            root.reload();
        }
    }

    function reload(): void {
        if (!settings) {
            values = ({});
            keys = [];
            return;
        }

        values = settings.values();
        keys = settings.keys();
    }

    function setValue(key: string, value: var): void {
        if (!settings)
            return;

        settings.setValue(key, value);
        values = settings.values();
    }

    onSettingsChanged: reload()
    Component.onCompleted: reload()

    title: plugin ? plugin.name : Tr.tr("Plugin")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.large
            spacing: Tokens.spacing.large

            StyledRect {
                implicitWidth: Math.round(Tokens.font.icon.large.pointSize * 3.2)
                implicitHeight: implicitWidth
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.plugin?.icon || "extension" // `??` would keep an empty icon, which a missing manifest icon produces
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.plugin?.name ?? ""
                    font: Tokens.font.title.medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (!root.plugin)
                            return "";
                        const author = root.plugin.author ?? Tr.tr("Unknown");
                        return root.plugin.version ? Tr.tr("By %1 · v%2").arg(author).arg(root.plugin.version) : Tr.tr("By %1").arg(author);
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text
                    text: root.plugin?.description ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
            }
        }

        SectionHeader {
            first: true
            text: Tr.tr("Plugin")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Enabled")
            subtext: root.plugin?.enabled ? Tr.tr("Loaded into the shell") : Tr.tr("Not loaded")
            checked: root.plugin?.enabled ?? false
            onToggled: {
                if (root.plugin)
                    Plugins.setPluginEnabled(root.plugin.id, checked);
            }
        }

        SectionHeader {
            text: Tr.tr("Settings")
            visible: root.keys.length > 0
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: root.keys.length === 0
            text: Tr.tr("This plugin has no configurable settings.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.keys

            delegate: PluginSettingRow {
                required property string modelData
                required property int index

                settingKey: modelData
                meta: root.settings ? root.settings.metaFor(modelData) : null
                value: root.values[modelData]
                first: index === 0
                last: index === root.keys.length - 1
                onEdited: value => root.setValue(modelData, value)
            }
        }

        SectionHeader {
            text: Tr.tr("Problems")
            visible: (root.plugin?.entryPointErrors ?? []).length > 0
        }

        Repeater {
            model: root.plugin?.entryPointErrors ?? []

            delegate: StyledText {
                required property string modelData

                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.small
                Layout.topMargin: Tokens.spacing.small
                text: modelData
                color: Colours.palette.m3error
                font: Tokens.font.body.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }

        SectionHeader {
            text: Tr.tr("Details")
        }

        InfoRow {
            first: true
            icon: "badge"
            label: Tr.tr("Plugin ID")
            value: root.plugin?.id ?? ""
        }

        InfoRow {
            icon: "folder"
            label: Tr.tr("Directory")
            value: root.plugin?.dir ?? ""
        }

        InfoRow {
            last: !root.managed
            icon: "extension"
            label: Tr.tr("Entry points")
            value: root.plugin ? String(root.plugin.entryPoints.length) : ""
        }

        SectionHeader {
            visible: root.managed
            text: Tr.tr("Manage")
        }

        DialogRowButton {
            visible: root.managed
            rootParent: root
            icon: "delete_forever"
            label: Tr.tr("Remove plugin")
            header: Tr.tr("Remove %1?").arg(root.plugin?.name ?? "")
            acceptLabel: Tr.tr("Remove")
            separateContent: true

            content: Component {
                StyledText {
                    anchors.fill: parent
                    text: Tr.tr("This deletes the plugin directory. Its saved settings are kept.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    verticalAlignment: Text.AlignTop
                }
            }

            onAccepted: {
                const id = root.plugin?.id;
                if (!id)
                    return;

                if (Plugins.removePlugin(id))
                    root.nState.closeSubPage();
                else
                    Toaster.toast(Tr.tr("Could not remove plugin"), Plugins.removeError, "error");
            }
        }
    }
}
