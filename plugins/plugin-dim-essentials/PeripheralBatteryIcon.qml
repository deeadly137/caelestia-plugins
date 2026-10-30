pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.services
import qs.utils

// Batteries of devices that are not the laptop's own: mice, keyboards, headsets. Provided by this
// plugin so the icon disappears together with it.
Item {
    id: root

    required property SettingsObject settings

    readonly property bool isHorizontal: Hooks.barPosition(Config) === "top" || Hooks.barPosition(Config) === "bottom"
    readonly property var excluded: Array.isArray(root.settings.peripheralBatteryExcluded) ? root.settings.peripheralBatteryExcluded : []

    visible: root.settings.showPeripheralBattery === true
    implicitWidth: visible ? layout.implicitWidth : 0
    implicitHeight: visible ? layout.implicitHeight : 0

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    GridLayout {
        id: layout

        columns: root.isHorizontal ? -1 : 1
        rows: root.isHorizontal ? 1 : -1
        flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium / 2
        rowSpacing: Tokens.spacing.medium / 2

        Repeater {
            model: ScriptModel {
                values: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.isPresent && !root.excluded.some(e => e === d.model || e === d.nativePath)) // qmllint disable unresolved-type
            }

            MaterialIcon {
                required property UPowerDevice modelData

                animate: true
                text: {
                    if (modelData.state === UPowerDeviceState.Charging || modelData.state === UPowerDeviceState.PendingCharge)
                        return "battery_charging_full";
                    if (modelData.state === UPowerDeviceState.FullyCharged)
                        return "battery_full";
                    return Icons.getBatteryIcon(modelData.percentage, false);
                }
                color: modelData.percentage > 0.2 ? Colours.palette.m3secondary : Colours.palette.m3error
                fill: 1
            }
        }
    }
}
