pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property var content
    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    required property SearchBar search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}wallpaper `) || search.text === `${GlobalConfig.launcher.actionPrefix}wallpaper`
    onShowWallpapersChanged: {
        if (!showWallpapers)
            return;

        for (let category of Wallpapers.categories) {
            const walls = Wallpapers.grouped[category] || [];
            if (walls.some(w => w.path === Wallpapers.actualCurrent)) {
                currentWallpaperTab = category;
                break;
            }
        }
    }

    readonly property var currentList: showWallpapers ? wallpaperList.item : appList.item // Can be either ListView or PathView, so can't type properly
    property string currentWallpaperTab: "Main"
    readonly property var wallpaperTabs: Wallpapers.categories.map(category => ({
                id: category,
                text: category
            }))
    property string animState: showWallpapers ? "wallpapers" : "apps"

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    clip: true
    state: animState

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight)
                appList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                root.implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, wallpaperList.implicitWidth)
                root.implicitHeight: root.Tokens.sizes.launcher.wallpaperHeight + 56
                wallpaperList.active: true
            }
        }
    ]

    Behavior on animState {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: appList

        active: false

        anchors.fill: parent

        sourceComponent: AppList {
            objectName: "launcherAppList"

            search: root.search
            screenState: root.screenState
        }
    }

    Loader {
        id: wallpaperList

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.Tokens.sizes.launcher.wallpaperHeight

        sourceComponent: WallpaperList {
            objectName: "launcherWallpaperList"

            search: root.search
            screenState: root.screenState
            panels: root.panels
            content: root.content
            contentList: root
        }
    }

    Item {
        id: wallpaperTabsWrapper

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.medium
        implicitWidth: Math.min(parent.width - Tokens.padding.large * 2, tabsRow.implicitWidth)
        implicitHeight: tabsRow.implicitHeight + indicator.implicitHeight + 5

        visible: root.state === "wallpapers"

        Flickable {
            id: tabsFlickable

            anchors.fill: parent
            contentWidth: tabsRow.implicitWidth
            contentHeight: parent.height
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            ScrollBar.horizontal: StyledScrollBar {
                flickable: tabsFlickable
                active: tabsFlickable.moving || tabsFlickable.dragging
            }

            Row {
                id: tabsRow

                spacing: Tokens.spacing.large

                Repeater {
                    id: tabsRepeater

                    model: root.wallpaperTabs

                    delegate: Item {
                        id: tab

                        required property var modelData
                        required property int index

                        readonly property bool current: root.currentWallpaperTab === tab.modelData.id

                        implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: label.implicitHeight + Tokens.padding.small * 2

                        CustomMouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function onWheel(event: WheelEvent): void {
                                let idx = root.wallpaperTabs.findIndex(t => t.id === root.currentWallpaperTab);
                                if (event.angleDelta.y < 0 || event.angleDelta.x < 0)
                                    idx = Math.min(idx + 1, root.wallpaperTabs.length - 1);
                                else if (event.angleDelta.y > 0 || event.angleDelta.x > 0)
                                    idx = Math.max(idx - 1, 0);

                                root.currentWallpaperTab = root.wallpaperTabs[idx].id;
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.medium
                                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                onClicked: root.currentWallpaperTab = tab.modelData.id
                            }
                        }

                        StyledText {
                            id: label

                            anchors.centerIn: parent
                            text: tab.modelData.text
                            color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.large
                        }
                    }
                }
            }

            Item {
                id: indicator

                property int currentIndex: Math.max(0, root.wallpaperTabs.findIndex(t => t.id === root.currentWallpaperTab))
                property Item currentTab: tabsRepeater.itemAt(currentIndex)

                anchors.top: tabsRow.bottom
                anchors.topMargin: 5

                implicitWidth: currentTab ? currentTab.implicitWidth : 0
                implicitHeight: 3
                x: currentTab ? tabsRow.x + currentTab.x : 0

                onCurrentIndexChanged: {
                    if (!currentTab)
                        return;

                    const targetX = currentTab.x;
                    const targetWidth = currentTab.implicitWidth;
                    if (targetX < tabsFlickable.contentX)
                        tabsFlickable.contentX = targetX;
                    else if (targetX + targetWidth > tabsFlickable.contentX + tabsFlickable.width)
                        tabsFlickable.contentX = targetX + targetWidth - tabsFlickable.width;
                }

                clip: true

                StyledRect {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    implicitHeight: parent.implicitHeight * 2
                    color: Colours.palette.m3primary
                    radius: Tokens.rounding.full
                }

                Behavior on x {
                    Anim {}
                }

                Behavior on implicitWidth {
                    Anim {}
                }
            }
        }
    }

    Row {
        id: empty

        opacity: root.currentList?.count === 0 ? 1 : 0
        scale: root.currentList?.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: root.state === "wallpapers" ? "wallpaper_slideshow" : "manage_search"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.state === "wallpapers" ? Tr.tr("No wallpapers found") : Tr.tr("No results")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: root.state === "wallpapers" && Wallpapers.list.length === 0 ? Tr.tr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir)) : Tr.tr("Try searching for something else")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.screenState.launcher

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: root.screenState.launcher

        Anim {}
    }
}
