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

    property var rows: []

    // Entry point load failures and settings validation problems share one list.
    readonly property var problems: [...(plugin?.entryPointErrors ?? []), ...(settings?.warnings ?? [])]
    readonly property bool anyModified: rows.some(row => !row.header && row.modified)

    property Connections settingsConnections: Connections {
        target: root.settings

        function onChanged(): void {
            root.reload();
        }

        function onWarningsChanged(): void {
            root.reload();
        }
    }

    function groupLabel(path: string): string {
        const leaf = path.slice(path.lastIndexOf(".") + 1);
        const spaced = leaf.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_-]+/g, " ").trim();

        return spaced.length > 0 ? spaced[0].toUpperCase() + spaced.slice(1) : leaf;
    }

    function reload(): void {
        if (!settings) {
            rows = [];
            return;
        }

        const values = settings.flatValues();
        const keys = settings.keys();
        const result = [];
        let group = "";

        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            const dot = key.indexOf(".");
            const parent = dot === -1 ? "" : key.slice(0, dot);

            if (parent !== group) {
                group = parent;
                if (parent) {
                    const meta = settings.metaFor(parent);
                    result.push({
                        header: true,
                        key: parent,
                        label: meta && meta.label ? meta.label : groupLabel(parent),
                        description: meta && meta.description ? meta.description : ""
                    });
                }
            }

            result.push({
                header: false,
                key,
                meta: settings.metaFor(key),
                value: values[key],
                modified: settings.isModified(key)
            });
        }

        // Rows around a group header start and end a new card, so each group keeps its own
        // rounded container instead of running into the next one.
        for (let i = 0; i < result.length; i++) {
            if (result[i].header)
                continue;

            result[i].first = i === 0 || result[i - 1].header;
            result[i].last = i === result.length - 1 || result[i + 1].header;
        }

        rows = result;
    }

    function setValue(key: string, value: var): void {
        if (!settings)
            return;

        settings.setValue(key, value);
        reload();
    }

    function resetSetting(key: string): void {
        if (!settings)
            return;

        settings.reset(key);
        reload();
    }

    onSettingsChanged: reload()
    Component.onCompleted: reload()

    title: plugin ? (plugin.displayName || plugin.name) : Tr.tr("Plugin")
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
                    text: root.plugin?.displayName || root.plugin?.name || ""
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
            visible: root.rows.length > 0 || root.anyModified
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: root.rows.length === 0
            text: Tr.tr("This plugin has no configurable settings.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.rows

            DelegateChooser {
                role: "header"

                DelegateChoice {
                    roleValue: true
                    delegate: SectionHeader {
                        required property var modelData

                        Layout.topMargin: Tokens.padding.small
                        text: modelData.label
                    }
                }
                DelegateChoice {
                    delegate: PluginSettingRow {
                        required property var modelData

                        settingKey: modelData.key
                        meta: modelData.meta
                        value: modelData.value
                        modified: modelData.modified
                        first: modelData.first
                        last: modelData.last
                        onEdited: value => root.setValue(modelData.key, value)
                        onReset: root.resetSetting(modelData.key)
                    }
                }
            }
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            visible: root.anyModified
            text: Tr.tr("Reset all")
            onClicked: {
                root.settings?.resetAll();
                root.reload();
            }
        }

        SectionHeader {
            text: Tr.tr("Problems")
            visible: root.problems.length > 0
        }

        Repeater {
            model: root.problems

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
            header: Tr.tr("Remove %1?").arg(root.plugin?.displayName || root.plugin?.name || "")
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
