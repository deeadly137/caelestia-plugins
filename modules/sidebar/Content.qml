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

Item {
    id: root

    required property Props props
    required property ScreenState screenState
    property var popouts
    property var utilities

    // Legacy escape hatch: a plugin may still replace the whole sidebar body wholesale. New plugins
    // should use `sidebar-page` entry points instead, which are additive and keep stock notifications.
    readonly property var pluginContent: Hooks.slot("sidebar.content")[0] ?? null
    readonly property bool legacyBody: root.pluginContent !== null

    readonly property var pluginPages: {
        CUtils.dependency(Plugins.entryPointsRevision);
        return Array.from(Plugins.entryPoints(EntryPointType.SidebarPage))
            .slice()
            .sort((a, b) => {
                const byOrder = (a.properties.order ?? 100) - (b.properties.order ?? 100);
                return byOrder !== 0 ? byOrder : (a.properties.name ?? "").localeCompare(b.properties.name ?? "");
            });
    }

    property int pageRevision: 0
    property string activePage: "notifications"
    property bool waitingForInitialPage: false

    // Stock notifications is always the first tab. Plugin pages follow, hiding their tab when the
    // page itself says it has nothing to show.
    readonly property var tabs: {
        void root.pageRevision;

        const result = [{
            id: "notifications",
            label: Tr.tr("Notifications"),
            icon: "notifications"
        }];

        for (let i = 0; i < root.pluginPages.length; i++) {
            const entry = root.pluginPages[i];
            const item = pageRepeater.itemAt(i)?.item;
            if (item && item.available === false)
                continue;

            result.push({
                id: root.entryPageId(entry),
                label: entry.properties.title ?? entry.properties.name ?? Tr.tr("Plugin"),
                icon: entry.properties.icon ?? "extension"
            });
        }

        return result;
    }

    readonly property int activeIndex: {
        for (let i = 0; i < root.tabs.length; i++)
            if (root.tabs[i].id === root.activePage)
                return i;
        return 0;
    }

    // A page can ask to stay loaded while the sidebar is hidden, e.g. while an answer streams.
    readonly property bool keepAlive: {
        void root.pageRevision;

        if (legacyLoader.item?.keepAlive === true)
            return true;

        for (let i = 0; i < pageRepeater.count; i++)
            if (pageRepeater.itemAt(i)?.item?.keepAlive === true)
                return true;

        return false;
    }

    // Injects the shell objects a page may want. Only declared properties are touched: assigning
    // to one the page does not declare throws and would abort the rest of the handler, which also
    // skipped the initial-tab selection.
    function injectPage(loader, page): void {
        if (!page)
            return;

        loader.injectProperties(page, {
            props: root.props,
            screenState: root.screenState,
            popouts: root.popouts,
            utilities: root.utilities
        });
    }

    function indexOfPage(id: string): int {
        for (let i = 0; i < root.tabs.length; i++)
            if (root.tabs[i].id === id)
                return i;
        return 0;
    }

    function entryPageId(entry): string {
        return "plugin:" + (entry.properties.name ?? "");
    }

    function preferredPage(): string {
        for (let i = 0; i < root.pluginPages.length; i++) {
            const entry = root.pluginPages[i];
            const item = pageRepeater.itemAt(i)?.item;
            if (item && item.available !== false && item.preferred === true)
                return root.entryPageId(entry);
        }
        return "notifications";
    }

    // Choose the initial tab only once every page has loaded, so a page's `preferred` property is
    // not missed just because EntryPointLoader compiles asynchronously.
    function tryApplyInitialPage(): void {
        if (!root.waitingForInitialPage)
            return;

        if (root.legacyBody) {
            root.waitingForInitialPage = false;
            return;
        }

        // The delegates may not exist yet when the body is completed; wait for the repeater to have
        // one loader per entry point before trusting the item list.
        if (pageRepeater.count < root.pluginPages.length)
            return;

        for (let i = 0; i < pageRepeater.count; i++)
            if (!pageRepeater.itemAt(i)?.item)
                return;

        root.waitingForInitialPage = false;
        root.activePage = root.preferredPage();
    }

    function ensureActivePage(): void {
        if (!root.tabs.some(tab => tab.id === root.activePage))
            root.activePage = root.preferredPage();
    }

    Component.onCompleted: {
        // The body is created after the sidebar opened, so `onSidebarChanged` does not fire for the
        // first open.
        root.waitingForInitialPage = true;
        root.tryApplyInitialPage();
    }

    Connections {
        target: root.screenState

        function onSidebarChanged(): void {
            if (!root.screenState.sidebar)
                return;
            root.waitingForInitialPage = true;
            root.tryApplyInitialPage();
        }
    }

    onTabsChanged: root.ensureActivePage()

    Loader {
        id: legacyLoader

        anchors.fill: parent
        active: root.legacyBody
        sourceComponent: root.pluginContent ? root.pluginContent.component : null

        onLoaded: {
            if (!item)
                return;
            for (const key in root.pluginContent.properties)
                item[key] = root.pluginContent.properties[key];
            root.injectPage(legacyLoader, item);
        }
    }

    GridLayout {
        id: layout

        anchors.fill: parent
        visible: !root.legacyBody
        columns: 1
        rowSpacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: 0

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    id: headerContainer

                    Layout.fillWidth: true
                    implicitHeight: 64
                    clip: true
                    visible: root.tabs.length > 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: 0

                        Repeater {
                            id: tabRepeater
                            model: root.tabs

                            delegate: Item {
                                id: tabBtn

                                required property var modelData

                                readonly property bool active: root.activePage === tabBtn.modelData.id

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                StateLayer {
                                    id: stateLayer

                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: Tokens.rounding.medium
                                    color: Colours.palette.m3onSurface
                                    onClicked: root.activePage = tabBtn.modelData.id
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall - 2

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: tabBtn.modelData.icon
                                        color: tabBtn.active ? Colours.palette.m3primary : stateLayer.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                        fontStyle: Tokens.font.icon.small
                                        fill: tabBtn.active ? 1 : 0

                                        Behavior on fill {
                                            Anim {
                                                type: Anim.DefaultEffects
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: tabBtn.modelData.label
                                        color: tabBtn.active ? Colours.palette.m3primary : stateLayer.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.label.medium
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: indicator

                        anchors.verticalCenter: parent.bottom
                        implicitHeight: 6

                        readonly property real tabWidth: (headerContainer.width - Tokens.padding.medium * 2) / Math.max(1, tabRepeater.count)
                        width: tabWidth - Tokens.padding.medium * 2
                        x: Tokens.padding.medium + root.activeIndex * tabWidth + (tabWidth - width) / 2

                        clip: true

                        StyledRect {
                            anchors.fill: parent
                            color: Colours.palette.m3primary
                            radius: Tokens.rounding.full
                        }

                        Behavior on x {
                            Anim {}
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 1

                    color: Colours.tPalette.m3outlineVariant
                    visible: headerContainer.visible
                }

                Item {
                    id: pageStack

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Item {
                        id: notificationsPage

                        width: parent.width
                        height: parent.height
                        x: root.activePage === "notifications" ? 0 : (root.activeIndex > 0 ? -width : width)
                        opacity: root.activePage === "notifications" ? 1 : 0
                        visible: opacity > 0

                        NotifDock {
                            objectName: "sidebarNotifications"

                            anchors.fill: parent
                            props: root.props
                            screenState: root.screenState
                        }

                        Behavior on x {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                    }

                    Repeater {
                        id: pageRepeater

                        model: root.legacyBody ? [] : root.pluginPages

                        delegate: EntryPointLoader {
                            id: pageLoader

                            required property var modelData

                            readonly property string pageId: root.entryPageId(modelData)
                            readonly property int tabIndex: root.indexOfPage(pageId)

                            width: pageStack.width
                            height: pageStack.height
                            x: root.activePage === pageId ? 0 : (tabIndex < root.activeIndex ? -width : width)
                            opacity: root.activePage === pageId ? 1 : 0
                            visible: opacity > 0

                            entryPoint: modelData

                            onItemChanged: {
                                root.pageRevision++;
                                if (!item)
                                    return;
                                root.injectPage(pageLoader, item);
                                // The page's own `visible` must follow the tab, because pages such as
                                // the AI assistant refresh on `onVisibleChanged`.
                                if (item instanceof Item)
                                    item.visible = Qt.binding(() => root.activePage === pageLoader.pageId);
                                root.tryApplyInitialPage();
                            }

                            onStatusChanged: {
                                root.pageRevision++;
                                root.tryApplyInitialPage();
                            }

                            Behavior on x {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }

                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.topMargin: Tokens.padding.large - layout.spacing
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}
