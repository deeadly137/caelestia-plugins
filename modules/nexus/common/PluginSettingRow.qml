pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Plugins
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
    property bool modified
    property bool first
    property bool last

    signal edited(value: var)
    signal reset()

    readonly property string labelText: meta && meta.label ? meta.label : keyLabel(settingKey)
    readonly property string description: meta && meta.description ? meta.description : ""
    readonly property string iconName: meta && meta.icon ? meta.icon : "tune"
    readonly property var options: meta && meta.options ? meta.options : []
    readonly property bool hasOptions: options.length > 0
    readonly property bool isBoolean: typeof value === "boolean"
    readonly property bool isNumber: typeof value === "number"
    readonly property bool isString: typeof value === "string"

    // Explicit inputType wins, but only when it matches the value; a mismatched type falls back
    // to inference and the backend reports it under Problems.
    readonly property int inputType: {
        const type = meta ? meta.inputType : SettingMeta.Default;

        if (type === SettingMeta.Slider && isNumber)
            return SettingMeta.Slider;
        if (type === SettingMeta.SpinBox && isNumber)
            return SettingMeta.SpinBox;
        if (type === SettingMeta.Switch && isBoolean)
            return SettingMeta.Switch;
        if (type === SettingMeta.TextField && isString)
            return SettingMeta.TextField;
        if (type === SettingMeta.BlobButton && hasOptions)
            return SettingMeta.BlobButton;
        if (type === SettingMeta.SplitButton && hasOptions)
            return SettingMeta.SplitButton;

        if (hasOptions)
            return SettingMeta.SplitButton;
        if (isBoolean)
            return SettingMeta.Switch;
        if (isNumber)
            return SettingMeta.SpinBox;
        return SettingMeta.TextField;
    }
    readonly property bool controlDisabled: meta ? meta.disabled : false
    readonly property int decimals: {
        const step = meta && meta.step > 0 ? meta.step : 0;
        if (step > 0 && step < 1)
            return Math.max(1, Math.ceil(-Math.log10(step)));
        return step >= 1 ? 0 : 2;
    }

    function keyLabel(key: string): string {
        const leaf = key.slice(key.lastIndexOf(".") + 1);
        const spaced = leaf.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_-]+/g, " ").trim();

        return spaced.length > 0 ? spaced[0].toUpperCase() + spaced.slice(1) : leaf;
    }

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
                visible: root.hasOptions && root.inputType !== SettingMeta.BlobButton
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.options

                    TextButton {
                        required property string modelData

                        text: modelData
                        isToggle: true
                        checked: modelData === root.value
                        enabled: !root.controlDisabled
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        font: Tokens.font.label.small
                        onClicked: root.edited(modelData)
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.hasOptions && root.inputType === SettingMeta.BlobButton
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.options

                    IconButton {
                        id: blobButton

                        required property string modelData
                        required property int index

                        isToggle: true
                        checked: modelData === root.value
                        enabled: !root.controlDisabled
                        icon: (root.meta && root.meta.optionIcons ? root.meta.optionIcons[index] : "") || "check"
                        type: IconButton.Filled
                        onClicked: root.edited(modelData)
                    }
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: !root.hasOptions && !root.isBoolean && !root.isNumber ? Tokens.sizes.nexus.textFieldWidth : -1
            active: !root.hasOptions
            visible: active
            enabled: !root.controlDisabled
            sourceComponent: root.inputType === SettingMeta.Slider
                ? sliderComponent
                : root.inputType === SettingMeta.Switch
                    ? switchComponent
                    : root.inputType === SettingMeta.SpinBox
                        ? numberComponent
                        : textComponent
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            visible: root.modified
            enabled: !root.controlDisabled
            type: IconButton.Text
            icon: "restart_alt"
            font: Tokens.font.icon.small
            onClicked: root.reset()
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
            from: root.meta && root.meta.hasMin ? root.meta.min : 0
            to: root.meta && root.meta.hasMax ? root.meta.max : 9999
            stepSize: root.meta && root.meta.step > 0 ? root.meta.step : 1
            value: root.value
            onValueModified: root.edited(value)
        }
    }

    Component {
        id: sliderComponent

        RowLayout {
            spacing: Tokens.spacing.small

            StyledSlider {
                id: slider

                Layout.preferredWidth: Tokens.sizes.nexus.textFieldWidth
                from: root.meta && root.meta.hasMin ? root.meta.min : 0
                to: root.meta && root.meta.hasMax ? root.meta.max : (root.meta && root.meta.hasMin ? root.meta.min + 1 : 1)
                stepSize: root.meta && root.meta.step > 0 ? root.meta.step : 0
                value: root.value
                onMoved: root.edited(value)
            }

            StyledText {
                Layout.preferredWidth: Tokens.padding.extraLarge * 2
                text: Number(root.value).toFixed(root.decimals)
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
                horizontalAlignment: Text.AlignRight
            }
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
