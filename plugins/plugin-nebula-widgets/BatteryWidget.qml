import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import M3Shapes
import Caelestia.Config
import qs.services
import deeadly137.nebulawidgets

Item {
    id: root

    property string shapeName: "Cookie12Sided"
    property real baseSize: 200
    property string colorRole: "secondary"
    readonly property var colors: Widgets.palette(colorRole)
    readonly property string family: Tokens.font.body.small.family
    readonly property string iconFamily: Tokens.font.icon.medium.family
    readonly property real gap: 14

    property real size: baseSize

    Behavior on size {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveSlowSpatial
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    readonly property var device: UPower.displayDevice
    readonly property bool available: device !== null && device !== undefined && device.isLaptopBattery && device.isPresent
    readonly property real level: available ? device.percentage : 0
    readonly property int percent: Math.round(level * 100)
    readonly property bool charging: available && device.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: available && !UPower.onBattery
    readonly property bool full: available && device.state === UPowerDeviceState.FullyCharged
    readonly property real timeToEmpty: available ? device.timeToEmpty : 0
    readonly property real timeToFull: available ? device.timeToFull : 0

    property real shownLevel: level

    Behavior on shownLevel {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
        }
    }

    readonly property bool critical: available && level <= 0.2
    readonly property bool halfway: available && level <= 0.5
    property color accent: !available ? Colours.palette.m3outline : critical ? Colours.palette.m3error : halfway ? Colours.palette.m3tertiary : Colours.palette.m3primary

    Behavior on accent {
        ColorAnimation {
            duration: Tokens.anim.durations.expressiveSlowEffects
        }
    }

    property real innerTarget: 0.4
    property real innerRatio: innerTarget
    property bool ready: false

    Behavior on innerRatio {
        enabled: root.ready

        NumberAnimation {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
        }
    }

    function remeasure(): void {
        if (ref.width <= 0)
            return;
        let least = ref.width / 2;
        for (let angle = 0; angle < 360; angle += 4)
            least = Math.min(least, ref.distanceAtAngle(angle));
        innerTarget = Math.max(0.2, least / ref.width);
        ready = true;
    }

    readonly property real ringWidth: size * 0.07
    readonly property real ringRadius: Math.min(size * 0.37, innerRatio * size - ringWidth / 2 - size * 0.04)
    readonly property real sweep: Math.min(360, 360 * shownLevel)
    readonly property real trackSweep: Math.max(0, 360 - sweep - gap * 2)

    function duration(seconds: real): string {
        const minutes = Math.round(seconds / 60);
        if (minutes < 1)
            return "";
        return minutes >= 60 ? Math.floor(minutes / 60) + "h " + (minutes % 60) + "m" : minutes + "m";
    }

    readonly property string status: {
        if (!available)
            return "No battery";
        if (full)
            return "Full";
        const time = duration(charging ? timeToFull : timeToEmpty);
        if (charging)
            return time !== "" ? time + " to full" : "Charging";
        if (pluggedIn)
            return "Plugged in";
        return time !== "" ? time + " left" : "On battery";
    }

    implicitWidth: size
    implicitHeight: size

    MaterialShape {
        id: body

        anchors.fill: parent
        shape: MaterialShape[root.shapeName] ?? MaterialShape.Cookie12Sided
        color: root.colors.fill
        animationDuration: Tokens.anim.durations.expressiveDefaultSpatial
        animationEasing: Tokens.anim.expressiveDefaultSpatial
    }

    MaterialShape {
        id: ref

        width: 200
        height: 200
        visible: false
        shape: body.shape
        animationDuration: 0

        onShapeChanged: Qt.callLater(root.remeasure)
        Component.onCompleted: Qt.callLater(root.remeasure)
    }

    Shape {
        anchors.fill: parent
        visible: root.available
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.ringWidth
            strokeColor: root.accent
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: Math.max(0.5, root.sweep)
            }
        }

        ShapePath {
            strokeWidth: root.trackSweep > 0 ? root.ringWidth : 0
            strokeColor: Qt.alpha(root.colors.text, 0.2)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90 + root.sweep + root.gap
                sweepAngle: root.trackSweep
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: root.ringRadius * 0.03

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.available
            spacing: root.ringRadius * 0.03

            Text {
                text: root.percent
                font.family: root.family
                font.pixelSize: root.ringRadius * (root.percent >= 100 ? 0.62 : 0.8)
                font.weight: Font.DemiBold
                color: root.colors.text
            }

            Text {
                anchors.top: parent.top
                anchors.topMargin: root.ringRadius * 0.12
                text: "%"
                font.family: root.family
                font.pixelSize: root.ringRadius * 0.27
                font.weight: Font.Medium
                color: root.colors.text
                opacity: 0.8
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: statusRow.implicitWidth + root.ringRadius * 0.24
            implicitHeight: statusRow.implicitHeight + root.ringRadius * 0.1
            radius: height / 2
            color: Qt.alpha(root.colors.text, 0.16)

            Row {
                id: statusRow

                anchors.centerIn: parent
                spacing: root.ringRadius * 0.05

                Text {
                    visible: root.charging
                    text: "bolt"
                    font.family: root.iconFamily
                    font.pixelSize: root.ringRadius * 0.26
                    color: root.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: Math.min(implicitWidth, root.ringRadius * 0.95)
                    text: root.status
                    elide: Text.ElideRight
                    font.family: root.family
                    font.pixelSize: root.ringRadius * (root.available ? 0.19 : 0.3)
                    font.weight: Font.Medium
                    color: root.colors.text
                }
            }
        }
    }
}
