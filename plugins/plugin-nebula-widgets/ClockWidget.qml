import QtQuick
import Quickshell
import M3Shapes
import Caelestia.Config
import qs.services
import deeadly137.nebulawidgets

Item {
    id: root

    property string shapeName: "Cookie12Sided"
    property real baseSize: 220
    property string colorRole: "primary"
    property bool showSeconds: true
    property bool showDate: true
    property bool showNumbers: false
    property string tickStyle: "hours"
    property bool live: true
    readonly property bool showTicks: tickStyle !== "off"
    readonly property var colors: Widgets.palette(colorRole)
    readonly property string family: Tokens.font.body.small.family

    property real size: baseSize

    Behavior on size {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveSlowSpatial
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    implicitWidth: size
    implicitHeight: size

    readonly property date now: clock.date
    readonly property real ticks: Math.floor((now.getTime() - now.getTimezoneOffset() * 60000) / 1000)
    readonly property real minuteTicks: Math.floor(ticks / 60)

    property real shownSecond: ticks * 6
    property real shownMinute: minuteTicks * 6
    property real shownHour: minuteTicks * 0.5

    Behavior on shownSecond {
        enabled: root.showSeconds

        NumberAnimation {
            duration: Tokens.anim.durations.expressiveSlowEffects
            easing: Tokens.anim.standard
        }
    }

    Behavior on shownMinute {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    Behavior on shownHour {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    readonly property real secondAngle: shownSecond % 360
    readonly property real minuteAngle: shownMinute % 360
    readonly property real hourAngle: shownHour % 360

    property int version: 0
    property bool ready: false
    property real innerTarget: 0.4
    property real innerRatio: innerTarget
    readonly property real inner: innerRatio * size

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
        version++;
        ready = true;
    }

    function edgeRatio(angle: real): real {
        if (ref.width <= 0)
            return 0.4;
        return Math.min(ref.distanceAtAngle(angle) / ref.width, innerTarget * 1.25);
    }

    readonly property real handWidth: Math.max(4, size * 0.06)
    readonly property real dotSize: Math.max(6, size * 0.06)
    readonly property real numberSize: Math.max(8, size * 0.075)
    readonly property real tickInset: showTicks ? size * 0.075 : 0

    SystemClock {
        id: clock

        enabled: root.live
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    MaterialShape {
        id: face

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
        shape: face.shape
        animationDuration: 0

        onShapeChanged: Qt.callLater(root.remeasure)
        Component.onCompleted: Qt.callLater(root.remeasure)
    }

    Repeater {
        model: root.tickStyle === "all" ? 60 : root.tickStyle === "hours" ? 12 : 0

        Rectangle {
            required property int index

            readonly property real angle: index * (root.tickStyle === "all" ? 6 : 30)
            readonly property bool major: root.tickStyle === "hours" || index % 5 === 0
            property real ratio: {
                root.version;
                return root.edgeRatio(angle);
            }
            readonly property real length: root.size * (major ? 0.07 : 0.035)
            readonly property real reach: ratio * root.size - root.size * 0.03 - length / 2

            Behavior on ratio {
                enabled: root.ready

                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveDefaultSpatial
                    easing: Tokens.anim.emphasizedDecel
                }
            }

            x: root.width / 2 + reach * Math.sin(angle * Math.PI / 180) - width / 2
            y: root.height / 2 - reach * Math.cos(angle * Math.PI / 180) - height / 2
            width: Math.max(major ? 2.5 : 1.5, root.size * (major ? 0.014 : 0.008))
            height: length
            radius: width / 2
            rotation: angle
            antialiasing: true
            color: Qt.alpha(root.colors.text, major ? 0.9 : 0.4)
        }
    }

    Repeater {
        model: root.showNumbers ? 12 : 0

        Text {
            required property int index

            readonly property real angle: (index + 1) * 30
            property real ratio: {
                root.version;
                return root.edgeRatio(angle);
            }
            readonly property real distance: ratio * root.size - root.numberSize * 1.1 - root.tickInset

            Behavior on ratio {
                enabled: root.ready

                NumberAnimation {
                    duration: Tokens.anim.durations.expressiveDefaultSpatial
                    easing: Tokens.anim.emphasizedDecel
                }
            }

            x: root.width / 2 + distance * Math.sin(angle * Math.PI / 180) - width / 2
            y: root.height / 2 - distance * Math.cos(angle * Math.PI / 180) - height / 2
            text: index + 1
            font.family: root.family
            font.pixelSize: root.numberSize
            font.weight: Font.DemiBold
            color: Qt.alpha(root.colors.text, 0.7)
        }
    }

    Text {
        id: dateText

        property real sideRatio: {
            root.version;
            return root.edgeRatio(180);
        }
        readonly property real room: sideRatio * root.size - root.tickInset - (root.showNumbers ? root.numberSize * 2.2 : root.size * 0.05)
        readonly property real reach: Math.max(0, Math.min(root.inner * 0.5, room - height / 2))

        Behavior on sideRatio {
            enabled: root.ready

            NumberAnimation {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.emphasizedDecel
            }
        }

        visible: root.showDate
        x: root.width / 2 - width / 2
        y: root.height / 2 - height / 2 + reach
        text: root.now.toLocaleString(Qt.locale("en_US"), "ddd d")
        font.family: root.family
        font.pixelSize: root.numberSize
        font.weight: Font.DemiBold
        color: root.colors.text
    }

    Rectangle {
        id: hourHand

        readonly property real length: root.inner * 0.55

        x: root.width / 2 - width / 2
        y: root.height / 2 - length
        width: root.handWidth
        height: length + width / 2
        radius: width / 2
        color: root.colors.text
        antialiasing: true

        transform: Rotation {
            origin.x: hourHand.width / 2
            origin.y: hourHand.length
            angle: root.hourAngle
        }
    }

    Rectangle {
        id: minuteHand

        readonly property real length: root.inner * 0.82

        x: root.width / 2 - width / 2
        y: root.height / 2 - length
        width: root.handWidth
        height: length + width / 2
        radius: width / 2
        color: Qt.alpha(root.colors.text, 0.6)
        antialiasing: true

        transform: Rotation {
            origin.x: minuteHand.width / 2
            origin.y: minuteHand.length
            angle: root.minuteAngle
        }
    }

    Rectangle {
        id: secondDot

        readonly property real distance: Math.max(root.inner * 0.5, (face.width > 0 ? face.distanceAtAngle(root.secondAngle) : root.inner) - root.dotSize * 1.4 - root.tickInset)

        visible: root.showSeconds
        x: root.width / 2 + distance * Math.sin(root.secondAngle * Math.PI / 180) - width / 2
        y: root.height / 2 - distance * Math.cos(root.secondAngle * Math.PI / 180) - height / 2
        width: root.dotSize
        height: width
        radius: width / 2
        color: root.colors.text
    }
}
