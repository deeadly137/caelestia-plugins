pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState
    property var popouts
    property var utilities
    readonly property Props props: Props {}

    readonly property bool shouldBeActive: screenState.sidebar && Config.sidebar.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 0.999
    property real slideAmount: (-implicitWidth - Config.border.thickness - Tokens.spacing.medium) * offsetScale
    anchors.leftMargin: slideAmount
    anchors.rightMargin: slideAmount
    implicitWidth: Tokens.sizes.sidebar.width
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)
        anchors.bottomMargin: 0

        // A plugin-provided body may need to stay loaded after the sidebar closes, e.g. while an
        // answer is still streaming.
        active: root.shouldBeActive || root.visible || content.item?.keepAlive === true

        sourceComponent: Content {
            implicitWidth: Tokens.sizes.sidebar.width - content.anchors.leftMargin - content.anchors.margins
            props: root.props
            screenState: root.screenState
            popouts: root.popouts
            utilities: root.utilities
        }
    }
}
