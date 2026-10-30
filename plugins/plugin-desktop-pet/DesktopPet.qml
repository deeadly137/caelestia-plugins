pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Plugins
import Caelestia.State
import qs.services
import qs.utils
import deeadly137.desktoppet

// Port of midnight-shell's Shimeji subsystem. The desktop-widget host places this on the top
// layer and restricts input to the union of the sprite regions exposed through `inputMask`.
Item {
    id: root

    required property SettingsObject settings

    readonly property int spriteCount: Math.max(1, settings.count ?? 1)
    readonly property real artScale: settings.scale ?? 1
    readonly property bool autoHide: settings.autoHide ?? false

    readonly property real borderThickness: Config.border.thickness
    readonly property var screen: Screens.screens.find(candidate => candidate.name === Config.screen) ?? null
    readonly property var bar: screen ? ShellState.componentsFor(screen)?.bar : null
    readonly property real barExclusiveZone: bar?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))

    readonly property real floorOffset: Config.bar.position === "bottom" ? barExclusiveZone : 0
    readonly property real ceilingOffset: Config.bar.position === "top" ? barExclusiveZone : 0
    readonly property real leftOffset: Config.bar.position === "left" ? barExclusiveZone : 0
    readonly property real rightOffset: Config.bar.position === "right" ? barExclusiveZone : 0

    readonly property var monitor: screen ? Hypr.monitorFor(screen) : null
    readonly property bool shouldBeVisible: !autoHide || (monitor?.activeWorkspace?.toplevels?.values.every(toplevel => toplevel.lastIpcObject?.floating) ?? true)

    // The host unions this with any other top-layer widget masks. When the pet is hidden the
    // region is emptied, otherwise an invisible sprite would keep swallowing clicks.
    readonly property Region inputMask: Region {
        regions: root.visible ? root.spriteMasks : []
    }

    property list<Region> spriteMasks: []
    property var extractedPaths: []

    visible: shouldBeVisible

    function resolvePackPath(): string {
        let path = String(settings.path ?? "").trim();
        if (!path)
            path = "assets/pusheen";

        if (path.startsWith("~"))
            path = Paths.home + path.slice(1);

        if (path.startsWith("/"))
            path = "file://" + path;
        else
            path = Qt.resolvedUrl(path).toString();

        path = path.split("?")[0];
        if (path.startsWith("file://"))
            path = path.slice(7);

        return path;
    }

    function getImgPath(): string {
        let path = resolvePackPath();
        if (!path)
            return "";

        if (path.endsWith(".zip")) {
            const extractDir = path.slice(0, -4) + "/";
            if (!extractor.running && !extractedPaths.includes(path)) {
                extractedPaths.push(path);
                extractor.arguments = ["-o", "-d", extractDir, path];
                extractor.running = true;
            }
            return extractDir;
        }

        return path.replace(/\/?$/, "/");
    }

    function registerSpriteMask(region: Region): void {
        if (!spriteMasks.includes(region))
            spriteMasks = [...spriteMasks, region];
    }

    function unregisterSpriteMask(region: Region): void {
        spriteMasks = spriteMasks.filter(mask => mask !== region);
    }

    Process {
        id: extractor

        running: false
        command: ["unzip"]
        workingDirectory: "/tmp"
    }

    Repeater {
        model: root.spriteCount

        ShimejiSprite {
            maskHost: root
            screenSize: Qt.size(root.width, root.height)
            borderThickness: root.borderThickness
            sizeScale: root.artScale
            floorOffset: root.floorOffset
            ceilingOffset: root.ceilingOffset
            leftOffset: root.leftOffset
            rightOffset: root.rightOffset
            imgPath: root.getImgPath()
        }
    }
}
