pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property bool shouldBeActive: Config.background.visualiser.enabled && (!Config.background.visualiser.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    // The bars have to clear the bar on whichever edge it sits on. `exclusiveZone` is the bar's
    // reserved thickness (border thickness while it is hidden), so use the same fallback as the
    // desktop widgets when no bar is instantiated yet.
    readonly property string barPosition: Hooks.barPosition(Config)
    readonly property int barExclusiveZone: ShellState.componentsFor(root.screen)?.bar?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
    readonly property real barMargin: Tokens.padding.large + Tokens.spacing.small

    opacity: shouldBeActive ? 1 : 0

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: true

        Loader {
            asynchronous: true
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Item {
                ServiceRef {
                    service: Audio.cava
                }

                VisualiserBars {
                    id: bars

                    anchors.fill: parent
                    anchors.margins: Config.border.thickness
                    anchors.leftMargin: root.barPosition === "left" ? root.barExclusiveZone + root.barMargin : root.barMargin
                    anchors.rightMargin: root.barPosition === "right" ? root.barExclusiveZone + root.barMargin : root.barMargin
                    anchors.topMargin: root.barPosition === "top" ? root.barExclusiveZone : Config.border.thickness
                    anchors.bottomMargin: root.barPosition === "bottom" ? root.barExclusiveZone : Config.border.thickness

                    values: Audio.cava.values
                    primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                    secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                    rounding: Tokens.rounding.medium * Config.background.visualiser.rounding
                    spacing: Tokens.spacing.extraSmall * Config.background.visualiser.spacing
                    animationDuration: Tokens.anim.durations.normal

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }
                    Behavior on anchors.rightMargin {
                        Anim {}
                    }
                    Behavior on anchors.topMargin {
                        Anim {}
                    }
                    Behavior on anchors.bottomMargin {
                        Anim {}
                    }
                }

                FrameAnimation {
                    running: root.opacity > 0 && !bars.settled
                    onTriggered: bars.advance(frameTime)
                }
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
