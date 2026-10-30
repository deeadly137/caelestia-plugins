import QtQuick
import M3Shapes
import Caelestia.Config
import deeadly137.nebulawidgets

Item {
    id: root

    property string shapeName: "Sunny"
    property real baseSize: 180
    property string content: ""
    property string colorRole: "tertiary"
    property real textScale: 1
    readonly property var palette: Widgets.palette(colorRole)
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

    MaterialShape {
        anchors.fill: parent
        shape: MaterialShape[root.shapeName] ?? MaterialShape.Sunny
        color: root.palette.fill
        animationDuration: Tokens.anim.durations.expressiveDefaultSpatial
        animationEasing: Tokens.anim.expressiveDefaultSpatial
    }

    Text {
        anchors.centerIn: parent
        width: root.size * 0.62
        height: root.size * 0.5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        text: root.content === "" ? "Edit me" : root.content
        opacity: root.content === "" ? 0.5 : 1
        font.family: root.family
        font.pixelSize: root.size * 0.16 * root.textScale
        font.weight: Font.DemiBold
        color: root.palette.text
    }
}
