pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Components
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    function openPlugin(plugin): void {
        nState.selectedPluginId = plugin.id;
        nState.openSubPage(1);
    }

    title: qsTr("Plugins")
    maxWidth: Tokens.sizes.nexus.maxContentWidth * 2
    horizontalPadding: Tokens.padding.extraLarge

    readonly property var installedPlugins: Array.from(Plugins.plugins).map(installedCard)
    readonly property var installedIds: installedPlugins.map(plugin => plugin.id)
    readonly property var storePlugins: Array.from(PluginList.plugins)
        .filter(plugin => installedIds.indexOf(plugin.id) === -1)
        .map(plugin => Object.assign({}, plugin, {
            installed: false
        }))

    function installedCard(plugin) {
        const banner = plugin.bannerSource ?? "";
        const logo = plugin.logoSource ?? "";

        return {
            id: plugin.id,
            name: plugin.name ?? plugin.id,
            author: plugin.author ?? qsTr("Unknown"),
            description: plugin.description ?? "",
            icon: plugin.icon ?? "extension",
            version: plugin.version ?? "",
            tags: Array.from(plugin.tags ?? []),
            banner: banner,
            logo: logo,
            image: banner,
            installed: true
        };
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            target: Plugins

            function onInstallFinished(pluginId, success, message): void {
                if (!success) {
                    Toaster.toast(qsTr("Plugin installation failed"), message, "error");
                    return;
                }

                const plugin = Array.from(Plugins.plugins).find(p => p.id === pluginId);

                // Installed plugins start disabled, since enabling one runs its QML
                const message = plugin && !plugin.enabled ? qsTr("%1 - enable it to use it").arg(pluginId) : pluginId;
                Toaster.toast(qsTr("Plugin installed"), message, "extension");

                if (plugin)
                    root.openPlugin(plugin);
            }
        }

        // // Empty state
        // StyledText {
        //     Layout.topMargin: Tokens.spacing.large
        //     Layout.alignment: Qt.AlignHCenter
        //     visible: root.allPlugins.length === 0
        //     text: qsTr("No plugins found in %1").arg("~/.config/caelestia/plugins")
        //     color: Colours.palette.m3outline
        //     font: Tokens.font.body.medium
        // }

        // Installed
        SectionHeader {
            first: true
            text: qsTr("Installed plugins")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.medium
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.installedPlugins.length === 0
            text: qsTr("No plugins installed.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.medium
        }

        PluginGrid {
            plugins: root.installedPlugins
        }

        // Store
        SectionHeader {
            text: qsTr("Browse plugins")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.medium
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: PluginList.loading
            text: qsTr("Loading plugins...")
            color: Colours.palette.m3outline
            font: Tokens.font.body.medium
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: PluginList.error.length > 0
            text: qsTr("Could not load plugin list: %1").arg(PluginList.error)
            color: Colours.palette.m3error
            font: Tokens.font.body.medium
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: !PluginList.loading && PluginList.error.length === 0 && root.storePlugins.length === 0
            text: qsTr("No plugins available.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.medium
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: Plugins.installError.length > 0
            text: qsTr("Installation failed: %1").arg(Plugins.installError)
            color: Colours.palette.m3error
            font: Tokens.font.body.medium
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        PluginGrid {
            plugins: root.storePlugins
        }

        // Repeater {
        //     model: root.enabledList

        //     NavRow {
        //         required property PluginManifest modelData
        //         required property int index

        //         first: index === 0
        //         last: index === root.enabledList.length - 1
        //         icon: modelData.icon || "extension"
        //         label: modelData.name
        //         status: qsTr("%1 · v%2").arg(modelData.author).arg(modelData.version)
        //         onClicked: root.openPlugin(modelData)
        //     }
        // }

        // // Available
        // SectionHeader {
        //     visible: root.availableList.length
        //     text: qsTr("Available")
        // }

        // Repeater {
        //     model: root.availableList

        //     NavRow {
        //         required property PluginManifest modelData
        //         required property int index

        //         first: index === 0
        //         last: index === root.availableList.length - 1
        //         icon: "extension_off"
        //         label: modelData.name
        //         status: qsTr("%1 · v%2").arg(modelData.author).arg(modelData.version)
        //         onClicked: root.openPlugin(modelData)
        //     }
        // }

        // // Issues
        // SectionHeader {
        //     visible: root.issueList.length
        //     text: qsTr("Issues")
        // }

        // Repeater {
        //     model: root.issueList

        //     InfoRow {
        //         required property PluginManifest modelData
        //         required property int index

        //         first: index === 0
        //         last: index === root.issueList.length - 1
        //         icon: "error"
        //         iconColour: Colours.palette.m3error
        //         label: modelData.name || modelData.dir
        //         subtext: modelData.error
        //     }
        // }
    }

    component PluginGrid: LazyGridView {
        id: grid

        property alias plugins: model.values

        Layout.fillWidth: true
        implicitHeight: animatedContentHeight

        cellWidth: 300 // Minimum cell width, elements stretch to fill complete view width
        rowSpacing: Tokens.spacing.large
        columnSpacing: Tokens.spacing.large
        estimatedRowHeight: 426 // Height per plugin card with default tokens and 2 line description, at nexus initial size

        asynchronous: true
        cacheBuffer: 400
        readyDelay: 1

        // Expressive default spatial spring params
        stiffness: 380
        damping: 0.8

        enterDuration: Tokens.anim.durations.expressiveDefaultEffects
        removeDuration: Tokens.anim.durations.expressiveDefaultEffects
        easing: Tokens.anim.expressiveDefaultEffects

        useCustomViewport: true
        viewport: {
            tWatcher.transform; // mapToItem is not reactive so use this to trigger updates
            return Qt.rect(0, root.flickable.contentY - mapToItem(root.flickable.contentItem, 0, 0).y, width, root.flickable.height);
        }

        model: ScriptModel {
            id: model
        }

        delegate: PluginCard {}

        // Frame animation to trigger move/resize springs
        FrameAnimation {
            running: grid.animating
            onTriggered: grid.step(frameTime)
        }

        TransformWatcher {
            id: tWatcher

            a: root.flickable.contentItem
            b: grid
        }
    }

    component PluginCard: StyledRect {
        id: plugin

        required property int index
        required property var modelData

        // TODO: it won't have the installed property, it would be more like checking instanceof PluginManifest vs another type
        readonly property bool isInstalled: modelData.installed ?? false

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.extraLarge

        implicitHeight: heroWrapper.implicitHeight + detailLayout.implicitHeight + detailLayout.anchors.topMargin + detailLayout.anchors.margins

        ClipRect {
            id: heroWrapper

            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: width * 9 / 16

            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
            radius: Tokens.rounding.extraLarge

            MaterialIcon {
                anchors.centerIn: parent
                text: "image"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.extraLarge
                opacity: 1 - heroImage.opacity
            }

            Image {
                id: heroImage

                anchors.fill: parent
                source: plugin.modelData.banner ?? plugin.modelData.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                retainWhileLoading: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }

            StyledRect {
                id: logoBadge

                readonly property real badgeSize: Math.round(Tokens.font.icon.large.pointSize * 3.2)

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Tokens.padding.large
                implicitWidth: badgeSize
                implicitHeight: badgeSize
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh

                Image {
                    id: logoImage

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    source: plugin.modelData.logo ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    mipmap: true
                    visible: source !== "" && status === Image.Ready
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !logoImage.visible
                    text: plugin.modelData.icon || "extension" // manifests report "" for a missing icon
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        ColumnLayout {
            id: detailLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heroWrapper.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.large
            anchors.topMargin: Tokens.spacing.medium

            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                text: plugin.modelData.name
                font: Tokens.font.title.builders.medium.width(110).build()
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            StyledText {
                Layout.topMargin: -parent.spacing / 2
                Layout.fillWidth: true
                text: qsTr("By %1").arg(plugin.modelData.author)
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            StyledText {
                Layout.topMargin: Tokens.spacing.extraSmall
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: plugin.modelData.description
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            Flow {
                Layout.topMargin: Tokens.spacing.small
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: plugin.modelData.tags

                    StyledRect {
                        required property string modelData

                        color: Colours.palette.m3tertiaryContainer
                        radius: Tokens.rounding.full

                        implicitWidth: tagText.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: tagText.implicitHeight + Tokens.padding.extraSmall * 2

                        StyledText {
                            id: tagText

                            anchors.centerIn: parent
                            text: parent.modelData
                            color: Colours.palette.m3onTertiaryContainer
                            font: Tokens.font.label.small
                        }
                    }
                }
            }

            Loader {
                Layout.topMargin: Tokens.spacing.medium
                Layout.fillWidth: true

                active: !plugin.isInstalled
                visible: active

                sourceComponent: ButtonRow {
                    spacing: Tokens.spacing.extraSmall

                    TextButton {
                        isRound: true
                        shapeMorph: true
                        fillWidth: true
                        readonly property bool installingThis: Plugins.installingPlugin === plugin.modelData.id
                        text: installingThis ? qsTr("Cancel") : qsTr("Install")
                        disabled: (Plugins.installing && !installingThis) || !(plugin.modelData.repo ?? "")
                        font: Tokens.font.body.builders.small.width(110).build()
                        onClicked: {
                            if (installingThis) {
                                Plugins.cancelInstall();
                                return;
                            }

                            Plugins.installPlugin(plugin.modelData.repo, plugin.modelData.path ?? "", plugin.modelData.id);
                        }
                    }

                    IconButton {
                        isRound: true
                        shapeMorph: true
                        icon: "home"
                        type: IconButton.Tonal
                        implicitWidth: implicitHeight + Tokens.padding.small * 2
                        onClicked: Qt.openUrlExternally(plugin.modelData.repo)
                    }
                }
            }
        }

        HoverHandler {
            cursorShape: plugin.isInstalled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: plugin.isInstalled
            acceptedButtons: Qt.LeftButton
            onTapped: root.openPlugin(plugin.modelData)
        }
    }
}
