// Utilities card for the PiP manager. It is the card half of the plugin: the pause switch and the
// 3×3 anchor grid write the same settings object the service reads, so changing either applies on
// the next window event without a restart.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property SettingsObject settings

    readonly property var positions: [
        {
            value: "top left",
            icon: "north_west"
        },
        {
            value: "top center",
            icon: "north"
        },
        {
            value: "top right",
            icon: "north_east"
        },
        {
            value: "middle left",
            icon: "west"
        },
        {
            value: "middle center",
            icon: "filter_center_focus"
        },
        {
            value: "middle right",
            icon: "east"
        },
        {
            value: "bottom left",
            icon: "south_west"
        },
        {
            value: "bottom center",
            icon: "south"
        },
        {
            value: "bottom right",
            icon: "south_east"
        }
    ]

    objectName: "pluginPipCard"

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                radius: Tokens.rounding.full
                color: root.settings.paused ? Colours.palette.m3surfaceVariant : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: "picture_in_picture_alt"
                    color: root.settings.paused ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: "Picture in Picture"
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.settings.paused ? "Auto-align paused" : `Auto-aligning to ${root.settings.position}`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            StyledSwitch {
                checked: !root.settings.paused
                onToggled: root.settings.paused = !checked
            }
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            rowSpacing: Tokens.spacing.extraSmall
            columnSpacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.positions

                delegate: StyledRect {
                    id: cell

                    required property var modelData

                    readonly property bool selected: root.settings.position === modelData.value

                    implicitWidth: Tokens.sizes.bar.innerWidth * 0.8
                    implicitHeight: Tokens.sizes.bar.innerWidth * 0.8
                    radius: Tokens.rounding.small
                    color: cell.selected ? Colours.palette.m3secondaryContainer : "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: cell.modelData.icon
                        color: cell.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StateLayer {
                        radius: cell.radius
                        onClicked: root.settings.position = cell.modelData.value
                    }
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
