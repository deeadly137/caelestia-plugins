pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import deeadly137.nebulawidgets

StyledWindow {
    id: window

    // The window object is not an item, so it inherits no screen from the scene. Tokens is used
    // directly on the root, so point it at this window's screen.
    Tokens.screen: screen?.name ?? ""

    name: "widget-corner"
    // Wide enough for the open panel (margin + width + flare); only the panel area is masked while
    // open, so keep the surface tight around it.
    implicitWidth: 344
    implicitHeight: 480
    anchors.bottom: true
    anchors.left: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Swap between two regions instead of resizing one: the input region is reapplied on every
    // mask object change, which is what the widget menu does and what the compositor follows
    // reliably while the panel animates open.
    mask: window.open ? winMask : hotMask

    Region {
        id: winMask

        width: window.width
        height: window.height
    }

    Region {
        id: hotMask

        y: window.height - window.hotHeight
        width: window.hotWidth
        height: window.hotHeight
    }

    WlrLayershell.layer: WlrLayer.Overlay

    property bool open: false
    property bool adding: false
    onOpenChanged: if (!open)
        adding = false

    readonly property color fill: Qt.alpha(Colours.tPalette.m3surface, 0.85)
    readonly property int rowHeight: 44
    readonly property int margin: 24
    readonly property int hotWidth: 300
    readonly property int hotHeight: 10
    readonly property int openWidth: 280
    readonly property int flare: 16
    readonly property string family: Tokens.font.body.small.family

    function addType(entry: var): void {
        const id = Widgets.add(entry.key, { screen: window.screen?.name ?? "" });
        window.adding = false;
        if (id !== "" && entry.picker)
            window.openWidget(id);
    }

    function openWidget(id: string): void {
        const cfg = Widgets.get(id);
        if (!cfg)
            return;
        const screen = Widgets.screenNamed(cfg.screen || (window.screen?.name ?? ""));
        if (!screen)
            return;
        const size = cfg.size ?? 200;
        const x = (cfg.x ?? -1) < 0 ? Math.round((screen.width - size) / 2) : cfg.x;
        const y = (cfg.y ?? -1) < 0 ? Math.round((screen.height - size) / 2) : cfg.y;
        Widgets.openMenu(id, screen.name, Qt.rect(screen.x + x, screen.y + y, size, size));
    }

    Timer {
        id: closeTimer

        interval: Tokens.anim.durations.expressiveFastEffects
        onTriggered: window.open = false
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                closeTimer.stop();
                window.open = true;
            } else {
                closeTimer.restart();
            }
        }
    }

    readonly property real targetWidth: open ? openWidth : hotWidth - flare * 2
    readonly property real targetHeight: open ? content.implicitHeight + Tokens.spacing.large * 2 : 0

    Rectangle {
        id: blob

        anchors.left: parent.left
        anchors.leftMargin: window.margin
        anchors.bottom: parent.bottom
        width: window.targetWidth
        height: window.targetHeight
        topLeftRadius: Tokens.rounding.extraLarge
        topRightRadius: Tokens.rounding.extraLarge
        color: window.fill
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveSlowEffects
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveSlowEffects
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        ColumnLayout {
            id: content

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.spacing.large
            visible: window.open
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                IconButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    type: IconButton.Text
                    visible: window.adding
                    icon: "arrow_back"
                    onClicked: window.adding = false
                }

                Text {
                    Layout.fillWidth: true
                    text: window.adding ? "Add widget" : "Widgets"
                    color: Colours.palette.m3onSurface
                    font.family: window.family
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                IconButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    type: IconButton.Text
                    visible: !window.adding
                    icon: "close"
                    onClicked: window.open = false
                }
            }

            Flickable {
                Layout.fillWidth: true
                visible: !window.adding
                implicitHeight: Math.min(contentHeight, window.rowHeight * 5)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: list

                    width: parent.width

                    Repeater {
                        model: Widgets.idModel

                        Item {
                            id: entry

                            required property string modelData
                            readonly property var cfg: Widgets.get(modelData) ?? ({})
                            readonly property bool on: cfg.enabled === true

                            width: list.width
                            height: window.rowHeight

                            HoverHandler {
                                id: rowHover
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Tokens.rounding.medium
                                color: rowHover.hovered ? Qt.alpha(Colours.palette.m3onSurface, 0.06) : "transparent"
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.openWidget(entry.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.spacing.small
                                anchors.rightMargin: Tokens.spacing.small
                                spacing: Tokens.spacing.medium

                                MaterialShape {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    shape: MaterialShape[entry.cfg.shape ?? "Circle"] ?? MaterialShape.Circle
                                    color: Widgets.palette(entry.cfg.color).fill
                                    opacity: entry.on ? 1 : 0.4
                                    animationDuration: Tokens.anim.durations.expressiveSlowEffects
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: Widgets.label(entry.cfg)
                                    elide: Text.ElideRight
                                    color: entry.on ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                    font.family: window.family
                                    font.pixelSize: 14
                                }

                                IconButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    type: IconButton.Text
                                    icon: "delete"
                                    opacity: rowHover.hovered ? 1 : 0
                                    enabled: rowHover.hovered
                                    onClicked: Widgets.remove(entry.modelData)

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Tokens.anim.durations.expressiveFastEffects
                                        }
                                    }
                                }

                                StyledSwitch {
                                    checked: entry.on
                                    onToggled: Widgets.update(entry.modelData, { enabled: !entry.on })
                                }
                            }
                        }
                    }
                }
            }

            Column {
                Layout.fillWidth: true
                visible: window.adding

                Repeater {
                    model: window.adding ? Widgets.available() : []

                    Item {
                        id: option

                        required property var modelData

                        width: parent.width
                        height: window.rowHeight + Tokens.spacing.medium

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.rounding.medium
                            color: optionMouse.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.06) : "transparent"
                        }

                        MouseArea {
                            id: optionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.addType(option.modelData)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.spacing.small
                            anchors.rightMargin: Tokens.spacing.small
                            spacing: Tokens.spacing.medium

                            MaterialShape {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                shape: MaterialShape[option.modelData.shape] ?? MaterialShape.Circle
                                color: Widgets.palette(option.modelData.color).fill

                                Text {
                                    anchors.centerIn: parent
                                    text: option.modelData.icon
                                    font.family: Tokens.font.icon.medium.family
                                    font.pixelSize: 20
                                    color: Widgets.palette(option.modelData.color).text
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: option.modelData.title
                                    elide: Text.ElideRight
                                    color: Colours.palette.m3onSurface
                                    font.family: window.family
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: option.modelData.description
                                    elide: Text.ElideRight
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.family: window.family
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }

            IconTextButton {
                Layout.alignment: Qt.AlignHCenter
                visible: !window.adding
                icon: "add"
                text: "Add widget"
                type: IconTextButton.Filled
                onClicked: window.adding = true
            }
        }
    }

    Shape {
        anchors.left: blob.right
        anchors.bottom: parent.bottom
        width: window.flare
        height: window.flare
        visible: blob.height > window.flare
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: window.fill
            startX: window.flare
            startY: window.flare
            PathArc {
                x: 0
                y: 0
                radiusX: window.flare
                radiusY: window.flare
                direction: PathArc.Clockwise
            }
            PathLine {
                x: 0
                y: window.flare
            }
        }
    }
}
