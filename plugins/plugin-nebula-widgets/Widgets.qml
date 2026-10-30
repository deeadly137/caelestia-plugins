pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Shared widget store. Widgets are persisted separately from the plugin settings so the list can
// grow without turning into one giant generated settings row.
Singleton {
    id: root

    readonly property string storePath: `${Paths.state}/nebulawidgets.json`
    readonly property bool ready: loaded && !loading

    readonly property var types: ({
        battery: { title: "Battery", description: "Fills like water as you charge", icon: "battery_full", shape: "Cookie12Sided", size: 200, minSize: 120, maxSize: 480, color: "secondary" },
        calendar: { title: "Calendar", description: "Today, tap to open the month", icon: "calendar_month", shape: "Cookie9Sided", size: 200, minSize: 140, maxSize: 420, color: "tertiary" },
        clock: { title: "Clock", description: "An analog clock in a shape", icon: "schedule", shape: "Cookie12Sided", size: 220, minSize: 100, maxSize: 600, color: "primary" },
        image: { title: "Image", description: "Any picture, in a shape", picker: true, icon: "image", shape: "Clover4Leaf", size: 200, minSize: 80, maxSize: 600, color: "secondary" },
        text: { title: "Text", description: "A note on your desktop", icon: "sticky_note_2", shape: "Sunny", size: 180, minSize: 80, maxSize: 600, color: "tertiary" }
    })

    readonly property var shapes: ["Circle", "Square", "Slanted", "Arch", "Oval", "Pill", "Diamond", "Pentagon", "Gem", "Sunny", "VerySunny", "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided", "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Boom", "SoftBoom", "Flower", "Puffy", "PuffyDiamond", "PixelCircle", "Bun"]
    readonly property var colorRoles: ["primary", "secondary", "tertiary", "surface"]

    function palette(role: string): var {
        switch (role) {
        case "primary":
            return { fill: Colours.tPalette.m3primaryContainer, text: Colours.tPalette.m3onPrimaryContainer, accent: Colours.tPalette.m3primary };
        case "tertiary":
            return { fill: Colours.tPalette.m3tertiaryContainer, text: Colours.tPalette.m3onTertiaryContainer, accent: Colours.tPalette.m3tertiary };
        case "surface":
            return { fill: Colours.tPalette.m3surfaceContainerHigh, text: Colours.tPalette.m3onSurface, accent: Colours.tPalette.m3primary };
        default:
            return { fill: Colours.tPalette.m3secondaryContainer, text: Colours.tPalette.m3onSecondaryContainer, accent: Colours.tPalette.m3secondary };
        }
    }

    function label(widget: var): string {
        if (!widget)
            return "";
        if (widget.type === "image")
            return String(widget.source ?? "").split("/").pop() || "Image";
        if (widget.type === "text")
            return widget.source !== "" ? widget.source : "Note";
        return types[widget.type]?.title ?? widget.type ?? "";
    }

    function fileUrl(path: string): string {
        if (!path)
            return "";
        if (path.startsWith("file:") || path.startsWith("http:") || path.startsWith("https:"))
            return path;
        return Qt.resolvedUrl(path);
    }

    property string menuId: ""
    property string menuScreen: ""
    property real menuX: 0
    property real menuY: 0
    property real menuW: 0
    property real menuH: 0

    function openMenu(id: string, screenName: string, rect: var): void {
        menuScreen = screenName;
        menuX = rect.x;
        menuY = rect.y;
        menuW = rect.width;
        menuH = rect.height;
        menuId = id;
    }

    function closeMenu(): void {
        menuId = "";
    }

    property string dragId: ""
    property string dragSource: ""
    property real dragX: 0
    property real dragY: 0

    function screenAt(x: real, y: real): var {
        let best = Quickshell.screens[0] ?? null;
        let bestDistance = Infinity;
        for (const screen of Quickshell.screens) {
            const dx = Math.max(screen.x - x, 0, x - (screen.x + screen.width));
            const dy = Math.max(screen.y - y, 0, y - (screen.y + screen.height));
            const distance = dx * dx + dy * dy;
            if (distance < bestDistance) {
                bestDistance = distance;
                best = screen;
            }
        }
        return best;
    }

    function screenNamed(name: string): var {
        return Quickshell.screens.find(screen => screen.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function available(): var {
        return Object.keys(types)
            .filter(key => !types[key].single || first(key) === null)
            .map(key => Object.assign({ key: key }, types[key]));
    }

    function spawn(size: real, screenName: string): var {
        const screen = screenNamed(screenName);
        if (!screen)
            return { x: 0, y: 0 };
        const shift = list.length % 6 * 36;
        return {
            x: Math.max(0, Math.round((screen.width - size) / 2 + shift)),
            y: Math.max(0, Math.round((screen.height - size) / 2 + shift))
        };
    }

    property var list: []
    property var ids: []

    ListModel {
        id: idModel
    }

    readonly property alias idModel: idModel

    function hasRow(id: string): bool {
        for (let i = 0; i < idModel.count; i++) {
            if (idModel.get(i).modelData === id)
                return true;
        }
        return false;
    }

    onListChanged: {
        const next = list.map(widget => widget.id);
        for (let i = idModel.count - 1; i >= 0; i--) {
            if (!next.includes(idModel.get(i).modelData))
                idModel.remove(i);
        }
        for (const id of next) {
            if (!hasRow(id))
                idModel.append({ modelData: id });
        }
        if (next.join(",") !== ids.join(","))
            ids = next;
    }

    function get(id: string): var {
        return list.find(widget => widget.id === id) ?? null;
    }

    function first(type: string): var {
        return list.find(widget => widget.type === type) ?? null;
    }

    function add(type: string, props: var): string {
        const kind = types[type];
        if (!kind || !ready)
            return "";
        const screenName = props?.screen ?? (Quickshell.screens[0]?.name ?? "");
        if (screenName === "")
            return "";
        const id = `${type}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`;
        save(list.concat([Object.assign({
            id: id,
            type: type,
            enabled: true,
            shape: kind.shape,
            size: kind.size,
            color: kind.color,
            opacity: 1,
            textScale: 1,
            screen: screenName,
            source: ""
        }, spawn(kind.size, screenName), props ?? {})]));
        return id;
    }

    function update(id: string, props: var): void {
        if (!ready)
            return;
        save(list.map(widget => {
            if (widget.id !== id)
                return widget;
            const next = Object.assign({}, widget, props);
            const grows = props.size !== undefined && widget.size !== undefined && props.x === undefined && props.y === undefined;
            if (grows && (widget.x ?? -1) >= 0 && (widget.y ?? -1) >= 0) {
                const shift = (props.size - widget.size) / 2;
                next.x = Math.max(0, Math.round(widget.x - shift));
                next.y = Math.max(0, Math.round(widget.y - shift));
            }
            return next;
        }));
    }

    function raise(id: string): void {
        const mine = get(id)?.z ?? 0;
        const others = Math.max(0, ...list.filter(widget => widget.id !== id).map(widget => widget.z ?? 0));
        if (mine > others)
            return;
        update(id, { z: others + 1 });
    }

    function remove(id: string): void {
        if (!ready)
            return;
        save(list.filter(widget => widget.id !== id));
    }

    property bool loaded: false
    property bool loading: true
    property bool pending: false

    function parse(raw: string): var {
        try {
            const data = JSON.parse(raw);
            return Array.isArray(data) ? data : [];
        } catch (e) {
            return [];
        }
    }

    function apply(raw: string): void {
        list = parse(raw).filter(widget => widget && typeof widget.id === "string" && types[widget.type] !== undefined);
        loaded = true;
        loading = false;
    }

    function seed(): void {
        if (loaded)
            return;
        const screen = Quickshell.screens[0] ?? null;
        const kind = types.clock;
        list = screen ? [{
            id: "clock-default",
            type: "clock",
            enabled: true,
            shape: kind.shape,
            size: kind.size,
            color: kind.color,
            opacity: 1,
            textScale: 1,
            screen: screen.name,
            source: "",
            x: Math.round((screen.width - kind.size) / 2),
            y: Math.round((screen.height - kind.size) / 2),
            z: 0
        }] : [];
        loaded = true;
        loading = false;
        if (list.length > 0)
            save(list);
    }

    function save(next: var): void {
        list = next;
        if (!loaded)
            return;
        pending = true;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 250
        onTriggered: {
            root.pending = false;
            store.setText(JSON.stringify(root.list));
        }
    }

    FileView {
        id: store

        path: root.storePath
        printErrors: false
        onLoaded: root.apply(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.seed();
                return;
            }
            console.warn(`[nebulawidgets] failed to load ${root.storePath}: ${error}`);
            root.seed();
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Paths.state])
}
