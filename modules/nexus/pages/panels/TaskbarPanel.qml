pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Taskbar")
    isSubPage: true

    // Bar sides. The shell can draw the bar on any edge, but which edge is in use is decided by a
    // plugin through the `bar.position` hook, so the row below only appears while one offers
    // `bar.setPosition`.
    readonly property list<MenuItem> sideItems: [
        MenuItem {
            icon: "west"
            text: Tr.tr("Left")
            value: "left"
        },
        MenuItem {
            icon: "east"
            text: Tr.tr("Right")
            value: "right"
        },
        MenuItem {
            icon: "north"
            text: Tr.tr("Top")
            value: "top"
        },
        MenuItem {
            icon: "south"
            text: Tr.tr("Bottom")
            value: "bottom"
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Position. Stock dropdown (same widget as Language & region → Clock format): the value
        // comes from the hook, the choice goes back through it, so the plugin keeps owning the
        // setting. Kept first on the page because it changes the whole layout.
        SectionHeader {
            visible: Hooks.hasFunction("bar.setPosition")
            first: true
            text: Tr.tr("Position")
        }

        SelectRow {
            visible: Hooks.hasFunction("bar.setPosition")
            first: true
            last: true
            label: Tr.tr("Bar position")
            subtext: Tr.tr("Screen edge the taskbar sits on")
            menuItems: root.sideItems
            active: root.sideItems.find(item => item.value === Hooks.value("bar.position", GlobalConfig.bar.position)) ?? root.sideItems[0]
            onSelected: item => Hooks.call("bar.setPosition", [item.value])
        }

        // Behaviour
        SectionHeader {
            first: !Hooks.hasFunction("bar.setPosition")
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Persistent")
            subtext: Tr.tr("Keep the bar visible at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal the bar when the cursor reaches the screen edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the bar reveals")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // Components
        SectionHeader {
            text: Tr.tr("Components")
        }

        NavRow {
            first: true
            icon: "workspaces"
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "web_asset"
            text: Tr.tr("Active window")
            subtext: Tr.tr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "widgets"
            text: Tr.tr("Tray")
            subtext: Tr.tr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            text: Tr.tr("Status icons")
            subtext: Tr.tr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            last: true
            icon: "schedule"
            text: Tr.tr("Clock")
            subtext: Tr.tr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        // Scroll actions
        SectionHeader {
            text: Tr.tr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Scroll over the workspace indicator to switch workspaces")
            checked: Config.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: Tr.tr("Volume")
            subtext: Tr.tr("Scroll on the top half of the bar to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Brightness")
            subtext: Tr.tr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }

        // Page extensions, e.g. a plugin that exposes the bar position it owns.
        PluginPageExtensions {
            Layout.fillWidth: true
            page: "taskbar"
        }
    }
}
