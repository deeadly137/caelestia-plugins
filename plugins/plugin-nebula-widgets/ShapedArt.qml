import QtQuick
import QtQuick.Effects
import M3Shapes
import qs.components.controls

// An image clipped to a Material shape, with simple cover/pan controls. Animated images (GIF and
// friends) use AnimatedImage so they keep playing inside the shape.
Item {
    id: root

    property url source
    property size sourceSize
    property alias shape: fill.shape
    property alias color: fill.color
    property alias animationDuration: fill.animationDuration
    property alias animationEasing: fill.animationEasing
    property real zoom: 1
    property real panX: 0
    property real panY: 0

    readonly property bool animated: /\.(gif|apng|mng)$/i.test(String(root.source).split("?")[0])
    readonly property real aspect: media.implicitHeight > 0 ? media.implicitWidth / media.implicitHeight : 1
    readonly property real coverWidth: width * zoom * Math.max(1, aspect)
    readonly property real coverHeight: height * zoom * Math.max(1, 1 / aspect)
    readonly property real rangeX: Math.max(0, (coverWidth - width) / 2)
    readonly property real rangeY: Math.max(0, (coverHeight - height) / 2)
    readonly property Item media: root.animated ? animatedImage : image
    readonly property bool loading: media.status === Image.Loading
    readonly property bool hasImage: media.status === Image.Ready

    implicitWidth: 56
    implicitHeight: 56

    MaterialShape {
        id: fill

        anchors.fill: parent
        shape: MaterialShape.Cookie9Sided
        color: "transparent"
    }

    MaterialShape {
        id: mask

        anchors.fill: parent
        shape: fill.shape
        color: "black"
        animationDuration: fill.animationDuration
        animationEasing: fill.animationEasing
        layer.enabled: true
        visible: false
    }

    Item {
        id: cropBox

        anchors.fill: parent
        clip: true
        visible: false

        Image {
            id: image

            width: root.coverWidth
            height: root.coverHeight
            x: -root.rangeX * (1 + root.panX)
            y: -root.rangeY * (1 + root.panY)
            source: root.animated ? "" : root.source
            sourceSize: root.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        AnimatedImage {
            id: animatedImage

            width: root.coverWidth
            height: root.coverHeight
            x: -root.rangeX * (1 + root.panX)
            y: -root.rangeY * (1 + root.panY)
            source: root.animated ? root.source : ""
            sourceSize: root.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            playing: root.animated
        }
    }

    LoadingIndicator {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.6
        height: width
        visible: root.loading
        animated: root.loading
    }

    MultiEffect {
        anchors.fill: parent
        source: cropBox
        visible: root.hasImage
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
