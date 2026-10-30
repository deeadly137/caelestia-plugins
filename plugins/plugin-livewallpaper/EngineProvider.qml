pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Plugins
import qs.services

// Runs linux-wallpaperengine for a Wallpaper Engine scene, one process per monitor, and registers
// the shell's external wallpaper provider so the background window goes transparent while the
// engine's background-layer surface is visible.
Item {
    id: root

    required property SettingsObject settings

    readonly property string providerId: "deeadly137/livewall"
    readonly property string scenePath: String(root.settings.engineSource ?? "").trim()
    readonly property string sceneDir: root.scenePath.endsWith("/project.json") ? root.scenePath.slice(0, -"/project.json".length) : root.scenePath
    readonly property bool ready: root.sceneDir !== "" && CUtils.fileExists(root.sceneDir + "/project.json")

    property bool running: false
    property bool failed: false
    property string error: ""

    readonly property bool active: root.running && root.ready && !root.failed && screenProcesses.count > 0

    function engineArgs(screenName): var {
        const args = ["linux-wallpaperengine", "--screen-root", screenName, "--layer", "background"];
        if (root.settings.engineSilent ?? false)
            args.push("--silent");
        else
            args.push("--volume", String(Math.round(Number(root.settings.engineVolume ?? 0.15) * 100)));
        args.push(root.sceneDir);
        return args;
    }

    function fail(message): void {
        root.failed = true;
        root.running = false;
        root.error = message;
        console.warn(`livewall: ${message}`);
    }

    function start(): void {
        root.failed = false;
        root.error = "";

        if (!root.ready) {
            root.running = false;
            return;
        }

        root.running = true;
    }

    function restart(): void {
        root.running = false;
        root.failed = false;
        restartTimer.restart();
    }

    onActiveChanged: {
        if (root.active)
            Wallpapers.externalProvider = root.providerId;
        else if (Wallpapers.externalProvider === root.providerId)
            Wallpapers.externalProvider = "";
    }

    onScenePathChanged: root.restart()

    Component.onCompleted: root.restart()

    function onUnload(): void {
        root.running = false;
        if (Wallpapers.externalProvider === root.providerId)
            Wallpapers.externalProvider = "";
    }

    Connections {
        target: root.settings

        function onEngineSilentChanged() {
            root.restart();
        }

        function onEngineVolumeChanged() {
            root.restart();
        }
    }

    Timer {
        id: restartTimer

        interval: 150
        onTriggered: root.start()
    }

    Item {
        id: processHost

        visible: false

        Repeater {
            id: screenProcesses

            model: Quickshell.screens

            Item {
                id: screenSlot

                required property var modelData

                Process {
                    command: root.engineArgs(screenSlot.modelData.name)
                    running: root.running

                    onExited: code => {
                        if (root.running)
                            root.fail(`wallpaper engine exited with code ${code}`);
                    }
                }
            }
        }
    }
}
