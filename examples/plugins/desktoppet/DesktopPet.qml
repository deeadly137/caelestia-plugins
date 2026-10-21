import QtQuick

// The desktop-widget loader gives this item the size of the whole screen. Everything outside the
// pet stays transparent, so normal windows still cover it.
Item {
    id: root

    readonly property real petSize: Math.max(72, Math.min(width, height) * 0.1)

    Rectangle {
        id: pet

        width: root.petSize
        height: width
        radius: width / 2
        color: "#ffb4a9"
        border.width: Math.max(1, width * 0.02)
        border.color: "#8c4a3f"

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height * 0.65)

        Rectangle {
            width: pet.width * 0.12
            height: width
            radius: width / 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -pet.width * 0.2
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -pet.height * 0.08

            color: "#2f1511"
        }

        Rectangle {
            width: pet.width * 0.12
            height: width
            radius: width / 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: pet.width * 0.2
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -pet.height * 0.08

            color: "#2f1511"
        }

        Rectangle {
            width: pet.width * 0.34
            height: pet.width * 0.12
            radius: height / 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: pet.height * 0.2

            color: "#2f1511"
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            drag.target: pet
            drag.minimumX: 0
            drag.maximumX: root.width - pet.width
            drag.minimumY: 0
            drag.maximumY: root.height - pet.height

            onReleased: bob.restart()
        }
    }

    SequentialAnimation {
        id: bob

        loops: Animation.Infinite
        running: !dragArea.drag.active && root.width > 0

        NumberAnimation {
            target: pet
            property: "y"
            to: root.height * 0.55
            duration: 1600
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: pet
            property: "y"
            to: root.height * 0.65
            duration: 1600
            easing.type: Easing.InOutQuad
        }
    }
}
