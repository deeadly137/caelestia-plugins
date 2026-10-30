pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import deeadly137.nebulawidgets

// The widget canvas. It fills the bottom-layer desktop-widget host and keeps per-screen state in
// Widgets. The host reads `inputMask` so only the widgets (or the full screen while dragging)
// receive pointer input.
Item {
    id: window

    property string screenName: ""
    property bool dragging: false
    property var hovering: []

    readonly property var screenObj: Quickshell.screens.find(screen => screen.name === window.screenName) ?? null
    readonly property real screenX: screenObj?.x ?? 0
    readonly property real screenY: screenObj?.y ?? 0
    readonly property bool covered: screenObj ? (Hypr.monitorFor(screenObj)?.activeWorkspace?.hasFullscreen ?? false) : false

    function setHover(id: string, on: bool): void {
        if (hovering.includes(id) === on)
            return;
        const rest = hovering.filter(entry => entry !== id);
        hovering = on ? rest.concat([id]) : rest;
    }

    function stackOf(id: string): real {
        return (Widgets.get(id)?.z ?? 0) * 1000 + Widgets.ids.indexOf(id);
    }

    readonly property string topHover: hovering.reduce((best, id) => best === "" || stackOf(id) > stackOf(best) ? id : best, "")

    property Region fullMask: Region {
        width: window.width
        height: window.height
    }
    // One region per visible widget, so the gaps between widgets stay click-through.
    readonly property list<Region> slotMasks: {
        const revision = maskRevision; // Re-evaluate when a slot moves, resizes, or loads
        const masks = [];
        for (let i = 0; i < repeater.count; i++) {
            const loader = repeater.itemAt(i);
            if (loader?.active && loader.widgetMask)
                masks.push(loader.widgetMask);
        }
        return revision >= 0 ? masks : [];
    }
    property int maskRevision: 0

    readonly property Region inputMask: Region {
        regions: window.dragging ? [window.fullMask] : window.slotMasks
    }

    function refreshMasks(): void {
        maskRevision++;
    }

    Component {
        id: imageWidget

        ImageWidget {
            shapeName: parent?.cfg?.shape ?? "Clover4Leaf"
            colorRole: parent?.cfg?.color ?? "secondary"
            baseSize: parent?.cfg?.size ?? 200
            path: parent?.cfg?.source ?? ""
            cropZoom: parent?.cfg?.zoom ?? 1
            cropX: parent?.cfg?.panX ?? 0
            cropY: parent?.cfg?.panY ?? 0
        }
    }

    Component {
        id: textWidget

        TextWidget {
            shapeName: parent?.cfg?.shape ?? "Sunny"
            colorRole: parent?.cfg?.color ?? "tertiary"
            textScale: parent?.cfg?.textScale ?? 1
            baseSize: parent?.cfg?.size ?? 180
            content: parent?.cfg?.source ?? ""
        }
    }

    Component {
        id: batteryWidget

        BatteryWidget {
            shapeName: parent?.cfg?.shape ?? "Cookie12Sided"
            colorRole: parent?.cfg?.color ?? "secondary"
            baseSize: parent?.cfg?.size ?? 200
        }
    }

    Component {
        id: calendarWidget

        CalendarWidget {
            shapeName: parent?.cfg?.shape ?? "Cookie9Sided"
            colorRole: parent?.cfg?.color ?? "tertiary"
            baseSize: parent?.cfg?.size ?? 200
            openShapeName: parent?.cfg?.openShape ?? ""
        }
    }

    Component {
        id: clockWidget

        ClockWidget {
            live: !window.covered
            shapeName: parent?.cfg?.shape ?? "Cookie12Sided"
            colorRole: parent?.cfg?.color ?? "primary"
            baseSize: parent?.cfg?.size ?? 220
            showSeconds: parent?.cfg?.seconds ?? true
            showDate: parent?.cfg?.date ?? true
            showNumbers: parent?.cfg?.numbers ?? false
            tickStyle: parent?.cfg?.tickStyle ?? "hours"
        }
    }

    Repeater {
        id: repeater

        model: Widgets.idModel
        onItemAdded: window.refreshMasks()
        onItemRemoved: window.refreshMasks()

        Loader {
            id: slot

            required property string modelData

            readonly property var cfg: Widgets.get(modelData) ?? ({})
            readonly property real maxX: Math.max(0, window.width - width)
            readonly property real maxY: Math.max(0, window.height - height)
            readonly property bool ghost: !!cfg.screen && Widgets.dragId === modelData && Widgets.dragSource !== window.screenName
            readonly property real restX: ghost ? Widgets.dragX - window.screenX
                : (cfg.x ?? -1) < 0 ? (window.width - width) / 2 : Math.min(cfg.x, maxX)
            readonly property real restY: ghost ? Widgets.dragY - window.screenY
                : (cfg.y ?? -1) < 0 ? (window.height - height) / 2 : Math.min(cfg.y, maxY)
            readonly property bool isTop: window.topHover === modelData
            readonly property real offX: ghost ? 0 : ((cfg.size ?? width) - width) / 2
            readonly property real offY: ghost ? 0 : ((cfg.size ?? height) - height) / 2
            readonly property var widgetMask: slotMask

            z: cfg.z ?? 0
            opacity: cfg.opacity ?? 1
            active: cfg.enabled === true && Widgets.types[cfg.type] !== undefined && (ghost || !cfg.screen || cfg.screen === window.screenName)
            x: restX + offX + (drag.active ? drag.translation.x : 0)
            y: restY + offY + (drag.active ? drag.translation.y : 0)
            width: item?.implicitWidth ?? 0
            height: item?.implicitHeight ?? 0

            onActiveChanged: window.refreshMasks()
            onXChanged: window.refreshMasks()
            onYChanged: window.refreshMasks()
            onWidthChanged: window.refreshMasks()
            onHeightChanged: window.refreshMasks()

            sourceComponent: cfg.type === "image" ? imageWidget : cfg.type === "text" ? textWidget : cfg.type === "clock" ? clockWidget : cfg.type === "calendar" ? calendarWidget : cfg.type === "battery" ? batteryWidget : null

            Region {
                id: slotMask

                item: slot
            }

            HoverHandler {
                enabled: !slot.ghost
                blocking: false
                onHoveredChanged: window.setHover(slot.modelData, hovered)
            }

            TapHandler {
                enabled: !slot.ghost && slot.isTop
                gesturePolicy: TapHandler.DragThreshold
                onPressedChanged: if (pressed)
                    Widgets.raise(slot.modelData)
            }

            TapHandler {
                enabled: !slot.ghost && slot.isTop
                acceptedButtons: Qt.RightButton
                onTapped: Widgets.openMenu(slot.modelData, window.screenName, Qt.rect(window.screenX + slot.x, window.screenY + slot.y, slot.width, slot.height))
            }

            DragHandler {
                id: drag

                target: null
                enabled: !slot.ghost && (slot.isTop || drag.active)
                cursorShape: Qt.ClosedHandCursor

                function publish(): void {
                    Widgets.dragX = window.screenX + slot.restX + slot.offX + translation.x;
                    Widgets.dragY = window.screenY + slot.restY + slot.offY + translation.y;
                }

                onTranslationChanged: if (active)
                    publish()

                onActiveChanged: {
                    window.dragging = active;
                    if (active) {
                        Widgets.dragSource = window.screenName;
                        publish();
                        Widgets.dragId = slot.modelData;
                        return;
                    }
                    const roam = !!slot.cfg.screen;
                    const target = roam ? Widgets.screenAt(Widgets.dragX + slot.width / 2, Widgets.dragY + slot.height / 2) : window.screenObj;
                    if (!target) {
                        Widgets.dragId = "";
                        return;
                    }
                    const props = {
                        x: Math.round(Math.max(0, Math.min(Widgets.dragX - target.x, target.width - slot.width)) - slot.offX),
                        y: Math.round(Math.max(0, Math.min(Widgets.dragY - target.y, target.height - slot.height)) - slot.offY)
                    };
                    if (roam)
                        props.screen = target.name;
                    Widgets.update(slot.modelData, props);
                    Widgets.dragId = "";
                }
            }
        }
    }
}
