pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// One generated setting row for a plugin's SettingsObject/SettingMeta pair.
ConnectedRect {
    id: root

    property string settingKey
    property var meta
    property var value
    property bool first
    property bool last

    signal edited(value: var)

    readonly property string labelText: meta && meta.label ? meta.label : settingKey
    readonly property string description: meta && meta.description ? meta.description : ""
    readonly property string iconName: meta && meta.icon ? meta.icon : "tune"
    readonly property var options: meta && meta.options ? meta.options : []
    readonly property bool hasOptions: options.length > 0
    readonly property bool isBoolean: typeof value === "boolean"
    readonly property bool isNumber: typeof value === "number"

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + content.anchors.margins * 2

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Tokens.padding.extraSmall
            text: root.iconName
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.labelText
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text
                    text: root.description
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.hasOptions
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.options

                    TextButton {
                        required property string modelData

                        text: modelData
                        isToggle: true
                        checked: modelData === root.value
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        font: Tokens.font.label.small
                        onClicked: root.edited(modelData)
                    }
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: !root.hasOptions && !root.isBoolean && !root.isNumber ? Tokens.sizes.nexus.textFieldWidth : -1
            active: !root.hasOptions
            sourceComponent: root.isBoolean ? switchComponent : root.isNumber ? numberComponent : textComponent
        }
    }

    Component {
        id: switchComponent

        StyledSwitch {
            checked: root.value
            onToggled: root.edited(checked)
        }
    }

    Component {
        id: numberComponent

        StyledSpinBox {
            from: root.meta && root.meta.min >= 0 ? root.meta.min : 0
            to: root.meta && root.meta.max > 0 ? root.meta.max : 9999
            stepSize: root.meta && root.meta.step > 0 ? root.meta.step : 1
            value: root.value
            onValueModified: root.edited(value)
        }
    }

    Component {
        id: textComponent

        StyledTextField {
            text: root.value ?? ""
            onEditingFinished: root.edited(text)
        }
    }
}
