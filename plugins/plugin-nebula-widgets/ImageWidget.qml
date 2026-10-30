import QtQuick
import M3Shapes
import Caelestia.Config
import deeadly137.nebulawidgets

ShapedArt {
    id: root

    property string shapeName: "Clover4Leaf"
    property real baseSize: 200
    property string path: ""
    property string colorRole: "secondary"
    property real cropZoom: 1
    property real cropX: 0
    property real cropY: 0

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
    shape: MaterialShape[shapeName] ?? MaterialShape.Clover4Leaf
    color: hasImage ? "transparent" : Widgets.palette(colorRole).fill
    source: path === "" ? "" : Widgets.fileUrl(path)
    sourceSize: Qt.size(1200, 1200)
    zoom: cropZoom
    panX: cropX
    panY: cropY
    animationDuration: Tokens.anim.durations.expressiveDefaultSpatial
    animationEasing: Tokens.anim.expressiveDefaultSpatial
}
