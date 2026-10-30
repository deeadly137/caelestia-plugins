pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import deeadly137.nebulawidgets

// Widget manager for Nexus → Wallpaper & style → Widgets. Adding, enabling and removing lives
// here; shape, size, colour and source are changed by right-clicking the widget on the desktop.
ColumnLayout {
    id: root

    spacing: Tokens.spacing.extraSmall / 2

    Repeater {
        model: Widgets.idModel

        delegate: StyledRect {
            id: row

            required property string modelData

            readonly property var cfg: Widgets.get(modelData) ?? ({})

            Layout.fillWidth: true
            implicitHeight: rowLayout.implicitHeight + Tokens.padding.medium * 2
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.medium

            RowLayout {
                id: rowLayout

                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialShape {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    shape: MaterialShape[row.cfg.shape ?? "Circle"] ?? MaterialShape.Circle
                    color: Widgets.palette(row.cfg.color).fill
                    opacity: row.cfg.enabled === true ? 1 : 0.4
                    animationDuration: Tokens.anim.durations.expressiveSlowEffects
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Widgets.label(row.cfg)
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: `${Widgets.types[row.cfg.type]?.title ?? row.cfg.type} · ${row.cfg.screen ?? ""}`
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    type: IconButton.Text
                    icon: "delete"
                    onClicked: Widgets.remove(row.modelData)
                }

                StyledSwitch {
                    checked: row.cfg.enabled === true
                    onToggled: Widgets.update(row.modelData, { enabled: checked })
                }
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        visible: Widgets.idModel.count === 0
        implicitHeight: emptyText.implicitHeight + Tokens.padding.large * 2
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        StyledText {
            id: emptyText

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Tokens.padding.large * 2)
            text: "No widgets yet. Add one below, then right-click it on the desktop to change its shape, size and colour."
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium
        text: "Add widget"
        font: Tokens.font.title.small
    }

    Flow {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        spacing: Tokens.spacing.small

        Repeater {
            model: Widgets.available()

            IconTextButton {
                required property var modelData

                icon: modelData.icon
                text: modelData.title
                type: IconTextButton.Tonal
                onClicked: Widgets.add(modelData.key, Config.screen ? { screen: Config.screen } : {})
            }
        }
    }
}
