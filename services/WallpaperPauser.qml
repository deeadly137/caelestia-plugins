pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.State
import qs.services

// Single source of truth for whether background video/animated wallpapers should be playing.
//
// Two independent inputs: the user's "Play wallpaper" toggle (PersistentState) and an automatic
// pause while a fullscreen window is visible (Config.background.videoWallpaperPauseOnFullscreen). The user's
// toggle is never overwritten; plugins read `playing` instead of PersistentState so they pause
// together with the shell's own video renderer.
Singleton {
    id: root

    readonly property bool userWantsPlayback: PersistentState.wallpaperPlaying
    readonly property bool pauseOnFullscreen: GlobalConfig.background.videoWallpaperPauseOnFullscreen

    readonly property bool fullscreenActive: {
        const monitors = Hypr.monitors?.values ?? [];
        for (const monitor of monitors) {
            if (monitor?.activeWorkspace?.lastIpcObject?.hasfullscreen)
                return true;

            // A fullscreen game/video can also live on a visible special workspace
            const special = monitor?.lastIpcObject?.specialWorkspace?.name ?? "";
            if (special.length > 0) {
                const workspace = Hypr.workspaces?.values?.find(candidate => candidate.name === special);
                if (workspace?.lastIpcObject?.hasfullscreen)
                    return true;
            }
        }

        return false;
    }

    readonly property bool playing: root.userWantsPlayback && !(root.pauseOnFullscreen && root.fullscreenActive)
    readonly property bool paused: !root.playing
    readonly property string pauseReason: !root.userWantsPlayback ? "user" : root.playing ? "" : "fullscreen"
}
