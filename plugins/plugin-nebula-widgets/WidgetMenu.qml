pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import deeadly137.nebulawidgets

StyledWindow {
    id: window

    // The window object is not an item, so it inherits no screen from the scene. Tokens is used
    // directly on the root, so point it at this window's screen.
    Tokens.screen: screen?.name ?? ""

    name: "widget-menu"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: window.open ? cardMask : emptyMask

    WlrLayershell.layer: WlrLayer.Overlay

    property Region cardMask: Region { item: card }
    property Region emptyMask: Region {}
    property string imageTarget: ""

    readonly property string screenName: screen?.name ?? ""
    readonly property real screenX: screen?.x ?? 0
    readonly property real screenY: screen?.y ?? 0
    readonly property real screenWidth: screen?.width ?? width
    readonly property real screenHeight: screen?.height ?? height
    readonly property var cfg: Widgets.get(Widgets.menuId) ?? ({})
    readonly property var kind: Widgets.types[cfg.type] ?? ({ size: 200, minSize: 80, maxSize: 600, color: "secondary" })
    readonly property bool open: Widgets.menuId !== "" && Widgets.menuScreen === screenName && cfg.id !== undefined
    readonly property real gap: Tokens.spacing.medium
    readonly property real cardWidth: 352
    readonly property string family: Tokens.font.body.small.family

    function set(props: var): void {
        Widgets.update(Widgets.menuId, props);
    }

    function center(): void {
        const size = cfg.size ?? kind.size;
        set({
            x: Math.round((window.screenWidth - size) / 2),
            y: Math.round((window.screenHeight - size) / 2)
        });
    }

    function openImagePicker(): void {
        const id = Widgets.menuId;
        if (id === "")
            return;
        window.imageTarget = id;
        Widgets.closeMenu();
        imageDialog.open();
    }

    HyprlandFocusGrab {
        windows: [window]
        active: window.open
        onCleared: Widgets.closeMenu()
    }

    Connections {
        target: Hypr

        function onFocusedWorkspaceChanged(): void {
            if (window.open)
                Widgets.closeMenu();
        }

        function onFocusedMonitorChanged(): void {
            if (window.open)
                Widgets.closeMenu();
        }
    }

    FileDialog {
        id: imageDialog

        title: "Select an image"
        filterLabel: "Image files"
        filters: Images.validImageExtensions.concat(["gif", "apng"])

        onAccepted: path => {
            if (window.imageTarget !== "")
                Widgets.update(window.imageTarget, { source: path });
            window.imageTarget = "";
        }
        onRejected: window.imageTarget = ""
    }

    Rectangle {
        id: card

        readonly property real targetX: Widgets.menuX - window.screenX
        readonly property real targetY: Widgets.menuY - window.screenY
        readonly property real rightX: targetX + Widgets.menuW + window.gap

        width: window.cardWidth
        height: column.implicitHeight + Tokens.spacing.large * 2
        x: rightX + width + window.gap <= window.screenWidth ? rightX : Math.max(window.gap, targetX - width - window.gap)
        y: Math.max(window.gap, Math.min(targetY, window.screenHeight - height - window.gap))
        radius: Tokens.rounding.extraLarge
        color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.97)
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        opacity: window.open ? 1 : 0
        scale: window.open ? 1 : 0.92
        transformOrigin: Item.Left

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveSlowEffects
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialShape {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    shape: MaterialShape[window.cfg.shape ?? "Circle"] ?? MaterialShape.Circle
                    color: Widgets.palette(window.cfg.color).fill
                    animationDuration: Tokens.anim.durations.expressiveSlowEffects
                }

                Text {
                    Layout.fillWidth: true
                    text: Widgets.label(window.cfg)
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurface
                    font.family: window.family
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                IconButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    type: IconButton.Text
                    icon: "close"
                    onClicked: Widgets.closeMenu()
                }
            }

            StyledTextField {
                Layout.fillWidth: true
                visible: window.cfg.type === "text"
                text: window.cfg.source ?? ""
                placeholderText: "Write something"
                onTextEdited: window.set({ source: text })
            }

            RowLayout {
                Layout.fillWidth: true
                visible: window.cfg.type === "image"
                spacing: Tokens.spacing.small

                StyledTextField {
                    Layout.fillWidth: true
                    text: window.cfg.source ?? ""
                    placeholderText: "Choose an image"
                    onTextEdited: window.set({ source: text })
                }

                IconButton {
                    implicitWidth: 40
                    implicitHeight: 40
                    type: IconButton.Tonal
                    icon: "folder_open"
                    onClicked: window.openImagePicker()
                }
            }

            Flickable {
                id: shapeFlick

                Layout.fillWidth: true
                implicitHeight: 40
                contentWidth: shapeRow.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                WheelHandler {
                    onWheel: event => {
                        const max = Math.max(0, shapeFlick.contentWidth - shapeFlick.width);
                        shapeFlick.contentX = Math.max(0, Math.min(max, shapeFlick.contentX - event.angleDelta.y));
                    }
                }

                Row {
                    id: shapeRow

                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: Widgets.shapes

                        Rectangle {
                            id: chip

                            required property string modelData
                            readonly property bool active: modelData === window.cfg.shape

                            width: 40
                            height: 40
                            radius: active ? height / 2 : Tokens.rounding.medium
                            color: active ? Colours.tPalette.m3secondaryContainer : chipMouse.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : "transparent"

                            Behavior on radius {
                                NumberAnimation {
                                    duration: Tokens.anim.durations.expressiveSlowEffects
                                    easing: Tokens.anim.standard
                                }
                            }

                            MaterialShape {
                                anchors.centerIn: parent
                                width: 22
                                height: width
                                shape: MaterialShape[chip.modelData] ?? MaterialShape.Circle
                                color: chip.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                            }

                            MouseArea {
                                id: chipMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.set({ shape: chip.modelData })
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                Text {
                    text: "aspect_ratio"
                    font.family: Tokens.font.icon.medium.family
                    font.pixelSize: 22
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: ((window.cfg.size ?? window.kind.size) - window.kind.minSize) / Math.max(1, window.kind.maxSize - window.kind.minSize)
                    onInteraction: value => window.set({ size: Math.round((window.kind.minSize + value * (window.kind.maxSize - window.kind.minSize)) / 10) * 10 })
                }

                Text {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(window.cfg.size ?? window.kind.size)
                    font.family: window.family
                    font.pixelSize: 12
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                Text {
                    text: "opacity"
                    font.family: Tokens.font.icon.medium.family
                    font.pixelSize: 22
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: Math.max(0, Math.min(1, ((window.cfg.opacity ?? 1) - 0.2) / 0.8))
                    onInteraction: value => window.set({ opacity: Math.round((0.2 + value * 0.8) * 20) / 20 })
                }

                Text {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((window.cfg.opacity ?? 1) * 100) + "%"
                    font.family: window.family
                    font.pixelSize: 12
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: Widgets.colorRoles

                    Rectangle {
                        id: dot

                        required property string modelData
                        readonly property bool active: modelData === (window.cfg.color ?? window.kind.color)

                        implicitWidth: 36
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: Widgets.palette(modelData).fill
                        border.width: active ? 3 : 1
                        border.color: active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.set({ color: dot.modelData })
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    type: IconButton.Text
                    icon: "center_focus_strong"
                    onClicked: window.center()
                }

                IconButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    type: IconButton.Text
                    icon: "delete"
                    onClicked: {
                        const id = Widgets.menuId;
                        Widgets.closeMenu();
                        Widgets.remove(id);
                    }
                }
            }
        }
    }
}
