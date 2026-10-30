// MiDnight's sidebar body: a tab switcher over notifications, the AI assistant and the Arch news
// feed. The shell loads this through the `sidebar.content` hook, so disabling MiDnight Essentials
// brings the stock notifications-only sidebar back.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Plugins
import qs.components
import qs.components.controls
import qs.modules.sidebar
import qs.services
import deeadly137.dimessentials

Item {
    id: root

    property SettingsObject settings
    property var props
    property var screenState
    property var popouts
    property var utilities

    readonly property bool isBarHorizontal: Hooks.barPosition(Config) === "top" || Hooks.barPosition(Config) === "bottom"
    readonly property bool showPopoutSeparator: isBarHorizontal && root.screenState.sidebar && popouts && popouts.hasCurrent && popouts.currentName !== "dockhover" && popouts.currentName !== "dockcontext" && popouts.currentName !== "activewindow" && popouts.currentName !== "github"

    property string activeTab: "notifications"

    readonly property bool aiAvailable: root.settings.aiEnableOllama || root.settings.aiEnableOpenRouter === true || root.settings.aiEnableOpenClaw === true

    // Keeps the sidebar loaded while the assistant is still answering, even after it is closed.
    property bool keepAlive: aiAssistant.isStreaming

    Connections {
        target: root.settings

        function onAiEnableOllamaChanged() {
            root.checkTabs();
        }
        function onAiEnableOpenRouterChanged() {
            root.checkTabs();
        }
        function onAiEnableOpenClawChanged() {
            root.checkTabs();
        }
        function onShowNewsChanged() {
            root.checkTabs();
        }
    }

    Connections {
        target: root.screenState

        function onSidebarChanged() {
            if (root.screenState.sidebar) {
                root.activeTab = String(root.settings.initialSidebarTab || "notifications");
                root.checkTabs();
            }
        }
    }

    function checkTabs(): void {
        if (!root.aiAvailable && root.activeTab === "ai")
            root.activeTab = "notifications";
        if (root.settings.showNews === false && root.activeTab === "news")
            root.activeTab = "notifications";
    }

    Component.onCompleted: {
        // The body is created after the sidebar opened, so `onSidebarChanged` does not fire for the
        // first open; the initial tab is applied here too.
        root.activeTab = String(root.settings.initialSidebarTab || "notifications");
        root.checkTabs();
    }

    GridLayout {
        id: layout

        anchors.fill: parent
        columns: 1
        rowSpacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: root.isBarHorizontal ? 1 : 0

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Tab Switcher Header
                Item {
                    id: headerContainer
                    Layout.fillWidth: true
                    implicitHeight: 64
                    clip: true
                    visible: tabRepeater.count > 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: 0

                        Repeater {
                            id: tabRepeater
                            model: {
                                const tabs = [{
                                    id: "notifications",
                                    label: Tr.tr("Notifications"),
                                    icon: "notifications"
                                }];
                                if (root.aiAvailable)
                                    tabs.push({
                                        id: "ai",
                                        label: Tr.tr("AI Assistant"),
                                        icon: "smart_toy"
                                    });
                                if (root.settings.showNews !== false)
                                    tabs.push({
                                        id: "news",
                                        label: Tr.tr("News"),
                                        icon: "newspaper"
                                    });
                                return tabs;
                            }

                            delegate: Item {
                                id: tabBtn

                                required property var modelData

                                readonly property bool active: root.activeTab === modelData.id

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                StateLayer {
                                    id: stateLayer
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: Tokens.rounding.medium
                                    color: Colours.palette.m3onSurface
                                    onClicked: root.activeTab = tabBtn.modelData.id
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

                    // Sliding Indicator
                    Item {
                        id: indicator
                        anchors.verticalCenter: parent.bottom
                        implicitHeight: 6

                        property int activeIndex: {
                            const arr = tabRepeater.model;
                            for (let i = 0; i < arr.length; i++) {
                                if (arr[i].id === root.activeTab)
                                    return i;
                            }
                            return 0;
                        }
                        readonly property real tabWidth: (headerContainer.width - Tokens.padding.medium * 2) / tabRepeater.count
                        width: tabWidth - Tokens.padding.medium * 2
                        x: Tokens.padding.medium + activeIndex * tabWidth + (tabWidth - width) / 2

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

                // Divider
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colours.palette.m3outlineVariant
                    visible: headerContainer.visible
                }

                // Content Panel Stack
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    property int activeIndex: indicator.activeIndex

                    NotifDock {
                        objectName: "sidebarNotifications"
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "notifications" ? 0 : -width
                        opacity: root.activeTab === "notifications" ? 1 : 0
                        visible: opacity > 0
                        props: root.props
                        screenState: root.screenState

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

                    SidebarAi {
                        id: aiAssistant
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "ai" ? 0 : (indicator.activeIndex < 1 ? width : -width)
                        opacity: root.activeTab === "ai" ? 1 : 0
                        visible: opacity > 0
                        settings: root.settings

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

                    SidebarNews {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "news" ? 0 : width
                        opacity: root.activeTab === "news" ? 1 : 0
                        visible: opacity > 0

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

        // Utilities Separator
        StyledRect {
            visible: utilities && utilities.offsetScale < 1
            Layout.row: Hooks.barPosition(Config) === "bottom" ? 0 : (Hooks.barPosition(Config) === "top" ? 2 : 1)
            Layout.topMargin: Hooks.barPosition(Config) === "bottom" ? 0 : (visible ? 18 : 0)
            Layout.bottomMargin: Hooks.barPosition(Config) === "bottom" ? (visible ? 18 : 0) : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }

        // Popout Separator
        StyledRect {
            visible: root.showPopoutSeparator
            Layout.row: Hooks.barPosition(Config) === "bottom" ? 2 : 0
            Layout.topMargin: Hooks.barPosition(Config) === "top" ? 0 : 12
            Layout.bottomMargin: Hooks.barPosition(Config) === "top" ? 12 : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}
