pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.components.controls
import qs.services
import deeadly137.wallhaven

// Wallhaven browser shown as a sub-page of Nexus > Wallpaper & style.
Item {
    id: root

    required property SettingsObject settings

    property var selected: null
    property int selectedIndex: -1

    implicitHeight: layout.implicitHeight

    function selectAt(index): void {
        if (index < 0 || index >= service.results.length)
            return;
        root.selected = service.results[index];
        root.selectedIndex = index;
    }

    function clearSelection(): void {
        root.selected = null;
        root.selectedIndex = -1;
    }

    readonly property string selectionId: root.selected ? String(root.selected.id ?? "") : ""

    WallhavenService {
        id: service

        settings: root.settings
    }

    Connections {
        function onDownloaded(path): void {
            Toaster.toast("Wallpaper set", String(path).split("/").pop(), "image");
            root.clearSelection();
        }

        function onDownloadFailed(message): void {
            Toaster.toast("Wallhaven download failed", message, "error");
        }

        target: service
    }

    ColumnLayout {
        id: layout

        width: parent.width
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: searchField

                Layout.fillWidth: true
                placeholderText: "Search Wallhaven..."
                leadingIcon: "search"
                onAccepted: service.search(text)
            }

            CircularIndicator {
                implicitSize: 22
                visible: service.loading
            }

            IconButton {
                icon: "shuffle"
                type: IconButton.Tonal
                disabled: searchField.text.trim() === ""
                onClicked: service.search(searchField.text, {
                    "random": true
                })
            }

            IconButton {
                icon: "search"
                type: IconButton.Tonal
                disabled: searchField.text.trim() === ""
                onClicked: service.search(searchField.text)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (service.loading)
                        return "Searching...";
                    if (service.error !== "")
                        return service.error;
                    if (service.page === 0)
                        return "Search for wallpapers, or shuffle for something random";
                    if (service.results.length === 0)
                        return "No wallpapers found";
                    return `${service.results.length} wallpapers (page ${service.page} of ${service.lastPage})`;
                }
                color: service.error !== "" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            TextButton {
                text: "Load more"
                visible: service.page > 0 && service.page < service.lastPage && !service.loading
                onClicked: service.searchNext()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: service.wantsApiKey
            text: "Sketchy and NSFW results need an API key. Add one in the plugin settings."
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        GridView {
            id: grid

            Layout.fillWidth: true
            implicitHeight: 420
            visible: service.results.length > 0
            clip: true

            cellWidth: Math.max(120, Math.floor(width / 4))
            cellHeight: Math.floor(cellWidth * 0.62)

            model: service.results
            cacheBuffer: 1000

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: grid
            }

            delegate: Item {
                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                StateLayer {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.extraSmall / 2
                    radius: Tokens.rounding.medium
                    onClicked: root.selectAt(index)

                    ClipRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.medium

                        Image {
                            anchors.fill: parent
                            source: modelData.thumbs?.large || modelData.thumbs?.small || ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.medium
                        color: "transparent"
                        border.width: root.selectedIndex === index ? 2 : 0
                        border.color: Colours.palette.m3primary
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: root.selected !== null
            implicitHeight: detail.implicitHeight + Tokens.padding.medium * 2
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            ColumnLayout {
                id: detail

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: root.selected?.resolution ?? ""
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: {
                            const parts = [];
                            if (root.selected?.category)
                                parts.push(root.selected.category);
                            if (root.selected?.purity)
                                parts.push(root.selected.purity);
                            if (root.selected?.file_size)
                                parts.push(`${Math.round(root.selected.file_size / 1024 / 1024 * 10) / 10} MiB`);
                            return parts.join(" · ");
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }

                    IconButton {
                        icon: "close"
                        onClicked: root.clearSelection()
                    }
                }

                ClipRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    radius: Tokens.rounding.medium

                    Image {
                        anchors.fill: parent
                        source: root.selected?.path ?? ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: service.downloadError !== "" ? service.downloadError : `wallhaven.cc/w/${root.selectionId}`
                        color: service.downloadError !== "" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    TextButton {
                        text: service.downloading && service.downloadId === root.selectionId ? "Downloading..." : "Set as wallpaper"
                        enabled: !service.downloading
                        onClicked: service.download(root.selected)
                    }
                }
            }
        }
    }
}
