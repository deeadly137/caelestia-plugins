import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Row for a result returned by a `launcher-provider` plugin. The host appends the result object to
// the app list; it carries `name`, an optional `description`/`desc` and an optional `icon`.
Item {
    id: root

    required property var modelData
    required property var screenState

    signal activate

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.activate()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        MaterialIcon {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            text: root.modelData?.icon ?? "search"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.builders.large.scale(1.3).build()
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.verticalCenter: icon.verticalCenter

            implicitWidth: parent.width - icon.width
            implicitHeight: name.implicitHeight + desc.implicitHeight

            StyledText {
                id: name

                text: root.modelData?.name ?? ""
                font: Tokens.font.body.medium
            }

            StyledText {
                id: desc

                text: (root.modelData?.description || root.modelData?.desc) ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3outline

                elide: Text.ElideRight
                width: root.width - icon.width - Tokens.rounding.extraLargeIncreased

                anchors.top: name.bottom
            }
        }
    }
}
