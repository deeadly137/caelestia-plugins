// Port of midnight-shell's PipManager service. Picture in Picture windows are resized to a fraction
// of the screen and parked in one of nine quadrants, optionally on the focused monitor. It runs as
// a `custom` entry point, so it lives exactly as long as the plugin is enabled and reads this
// plugin's settings instead of the shell config.
//
// A window counts as PiP when its title contains "Picture in Picture" / "Picture-in-Picture",
// which is what Firefox, Chromium and mpv set. Dragging a PiP window more than 100 px switches the
// anchor quadrant for that window until it is closed or the setting changes.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import Caelestia.Plugins
import qs.services

QtObject {
    id: root

    required property SettingsObject settings

    property int lastPipX: -1
    property int lastPipY: -1
    property double lastPipMoveTime: 0
    property string tempPipPosition: ""
    property string lastPipMonitor: ""
    property string currentPipAddress: ""

    // Wayland exclusive zones and the QML bindings need a moment to settle after an event, so a
    // burst of window events only triggers one check.
    readonly property Timer updateDebouncer: Timer {
        interval: 100
        running: false
        repeat: false

        onTriggered: root.checkPip()
    }

    readonly property Connections hyprEvents: Connections {
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "closewindow" || n === "openwindow" || n === "windowtitle" || n === "changefloatingmode" || n === "activewindow" || n === "configreloaded" || n === "workspace" || n === "focusedmon")
                root.updateDebouncer.restart();
        }

        target: Hyprland
    }

    readonly property Instantiator monitorEvents: Instantiator {
        model: Hyprland.monitors.values

        delegate: Connections {
            required property var modelData

            function onLastIpcObjectChanged(): void {
                root.updateDebouncer.restart();
            }

            target: modelData
        }
    }

    readonly property Connections settingsEvents: Connections {
        function onPositionChanged(): void {
            root.tempPipPosition = "";
            root.lastPipMoveTime = Date.now();
            root.checkPip();
        }

        function onFollowFocusChanged(): void {
            root.lastPipMoveTime = Date.now();
            root.checkPip();
        }

        function onPausedChanged(): void {
            if (!root.settings.paused)
                root.checkPip();
        }

        target: root.settings
    }

    readonly property Connections barEvents: Connections {
        function onPositionChanged(): void {
            root.updateDebouncer.restart();
        }

        target: GlobalConfig.bar
    }

    readonly property Connections borderEvents: Connections {
        function onThicknessChanged(): void {
            root.updateDebouncer.restart();
        }

        target: GlobalConfig.border
    }

    function checkPip(): void {
        if (root.settings.paused)
            return;

        let foundPip = false;
        const toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            if (t && t.title && t.title.match(/Picture[- ]in[- ][Pp]icture/)) {
                root.movePip(t);
                foundPip = true;
            }
        }

        if (!foundPip) {
            root.currentPipAddress = "";
            root.lastPipX = -1;
            root.lastPipY = -1;
            root.tempPipPosition = "";
        }
    }

    function movePip(t: HyprlandToplevel): void {
        if (root.settings.paused)
            return;

        if (Hypr.activeToplevel && Hypr.activeToplevel.address === t.address)
            return; // Do not fight the user while the PiP window is focused.

        const addr = "address:0x" + t.address;

        if (root.currentPipAddress !== addr) {
            root.lastPipX = -1;
            root.lastPipY = -1;
            root.tempPipPosition = "";
            root.currentPipAddress = addr;
        }

        let monitor = t.workspace?.monitor || Hyprland.focusedMonitor;

        if (root.settings.followFocus)
            monitor = Hyprland.focusedMonitor;

        if (!monitor)
            return;

        if (root.lastPipMonitor !== monitor.name) {
            root.tempPipPosition = "";
            root.lastPipMonitor = monitor.name;
        }

        const transform = monitor.lastIpcObject?.transform || 0;
        const isVertical = transform % 2 !== 0;

        const rawWidth = monitor.width;
        const rawHeight = monitor.height;

        const monitorWidth = (isVertical ? rawHeight : rawWidth) / monitor.scale;
        const monitorHeight = (isVertical ? rawWidth : rawHeight) / monitor.scale;

        const sizeX = (t.lastIpcObject && t.lastIpcObject.size && t.lastIpcObject.size[0]) ? t.lastIpcObject.size[0] : 0;
        const sizeY = (t.lastIpcObject && t.lastIpcObject.size && t.lastIpcObject.size[1]) ? t.lastIpcObject.size[1] : 0;

        const currentX = (t.lastIpcObject && t.lastIpcObject.at && t.lastIpcObject.at.length > 0) ? t.lastIpcObject.at[0] : null;
        const currentY = (t.lastIpcObject && t.lastIpcObject.at && t.lastIpcObject.at.length > 1) ? t.lastIpcObject.at[1] : null;

        // A large jump between our last position and the current one means the user dragged the
        // window; snap it to the third of the screen it was dropped in.
        if (currentX !== null && currentY !== null && root.lastPipX !== -1 && root.lastPipY !== -1 && (Date.now() - root.lastPipMoveTime > 1000)) {
            const diffX = Math.abs(currentX - root.lastPipX);
            const diffY = Math.abs(currentY - root.lastPipY);

            if (diffX > 100 || diffY > 100) {
                const relX = currentX - monitor.x;
                const relY = currentY - monitor.y;

                const centerX = relX + sizeX / 2;
                const centerY = relY + sizeY / 2;

                let newPos = "";
                if (centerY < monitorHeight / 3)
                    newPos += "top";
                else if (centerY > monitorHeight * 2 / 3)
                    newPos += "bottom";
                else
                    newPos += "middle";

                if (centerX < monitorWidth / 3)
                    newPos += " left";
                else if (centerX > monitorWidth * 2 / 3)
                    newPos += " right";
                else
                    newPos += " center";

                root.tempPipPosition = newPos.trim();
            }
        }

        const baseSize = Math.min(monitorWidth, monitorHeight) / 4;
        const effectiveSizeY = sizeY > 0 ? sizeY : baseSize;
        const effectiveSizeX = sizeX > 0 ? sizeX : (effectiveSizeY * 16 / 9);

        const scaleFactor = baseSize / effectiveSizeY;
        const targetWidth = effectiveSizeX * scaleFactor;
        const targetHeight = effectiveSizeY * scaleFactor;

        const resizeX = Math.floor(Math.max(200, targetWidth));
        const resizeY = Math.floor(Math.max(150, targetHeight));

        const offset = Math.min(monitorWidth, monitorHeight) * 0.03;

        const barPosition = Hooks.barPosition(Config);

        let resLeft = 0;
        let resTop = 0;
        let resRight = 0;
        let resBottom = 0;

        // Bar thickness is the token inner width plus the padding the bar adds on both sides.
        // 40 is the token default; plugins cannot read attached tokens from a QtObject service.
        const padding = Math.max(GlobalConfig.appearance.padding.small, GlobalConfig.border.thickness);
        const barSize = 40 + padding * 2;

        if (barPosition === "left")
            resLeft += barSize;
        else if (barPosition === "right")
            resRight += barSize;
        else if (barPosition === "top")
            resTop += barSize;
        else if (barPosition === "bottom")
            resBottom += barSize;

        const availWidth = monitorWidth - resLeft - resRight - resizeX;
        const availHeight = monitorHeight - resTop - resBottom - resizeY;

        let baseX = monitor.x + resLeft;
        let baseY = monitor.y + resTop;

        const pos = root.tempPipPosition || root.settings.position || "";

        if (pos.includes("center"))
            baseX += availWidth / 2;
        else if (pos.includes("right"))
            baseX += availWidth - offset;
        else
            baseX += offset;

        if (pos.includes("middle"))
            baseY += availHeight / 2;
        else if (pos.includes("bottom"))
            baseY += availHeight - offset;
        else
            baseY += offset;

        const moveX = Math.floor(baseX);
        const moveY = Math.floor(baseY);

        root.lastPipX = moveX;
        root.lastPipY = moveY;
        root.lastPipMoveTime = Date.now();

        if (Hypr.usingLua) {
            Hypr.dispatch(`hl.dsp.window.resize({ x = ${resizeX}, y = ${resizeY}, window = "${addr}" })`);
            Hypr.dispatch(`hl.dsp.window.move({ x = ${moveX}, y = ${moveY}, relative = false, window = "${addr}" })`);
            Hypr.dispatch(`hl.dsp.window.set_prop({ prop = "keep_aspect_ratio", value = "true", window = "${addr}" })`);
        } else {
            Hypr.dispatch(`resizewindowpixel exact ${resizeX} ${resizeY},${addr}`);
            Hypr.dispatch(`movewindowpixel exact ${moveX} ${moveY},${addr}`);
            Hypr.dispatch(`setprop ${addr} keep_aspect_ratio true`);
        }
    }

    Component.onCompleted: root.checkPip()
}
