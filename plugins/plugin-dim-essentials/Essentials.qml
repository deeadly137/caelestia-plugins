// MiDnight Essentials service object. It lives for as long as the plugin is enabled and registers
// the MiDnight-specific behaviour into the shell's hook points:
//
//   bar.position                effective screen edge (left by default, MiDnight's side)
//   bar.setPosition             called by the Nexus taskbar page row to change that edge
//   wallpapers.categories       wallpaper folder tabs in the launcher
//   wallpapers.grouped          wallpapers per folder
//   wallpapers.categoryFor      folder name used by the Nexus wallpaper page
//   wallpapers.paused           pause video walls while a fullscreen window is visible
//   launcher.appVisible         hides apps hidden from this plugin's launcher buttons
//   launcher.itemActions        the per-app hide/show button
//   sidebar.content             the tabbed sidebar (notifications, AI, news)
//   utilities.openWithSidebar   keep utilities closed while the sidebar is open
//   drawers.wantsKeyboard       keyboard focus for the AI input and the dashboard terminal
//
// Everything is unregistered in `onUnload()`, so disabling the plugin leaves the stock shell.
pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Plugins
import qs.services
import qs.utils
import deeadly137.dimessentials

QtObject {
    id: root

    // The plugin id, used as the owner of every hook registration.
    readonly property string owner: "deeadly137/dimessentials"

    required property SettingsObject settings

    readonly property var hiddenApps: Array.isArray(root.settings.hiddenApps) ? root.settings.hiddenApps : []
    readonly property var barSides: ["left", "right", "top", "bottom"]

    // Video/animated wallpaper pause while a fullscreen window is visible. The shell keeps the
    // user's own playback toggle; this only masks playback through the `wallpapers.paused` hook.
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
    readonly property bool videoPaused: root.fullscreenActive && root.settings.pauseVideoOnFullscreen === true

    onVideoPausedChanged: Hooks.setValue("wallpapers.paused", root.owner, root.videoPaused)

    // Injected into every launcher app row. The component is self-contained; the host fills in
    // `entry` and `screenState`, and `settings` comes from the registration below.
    readonly property Component hideButton: Component {
        LauncherHideButton {}
    }

    // Replaces the stock notifications-only sidebar body. `settings` is bound here because the host
    // only assigns `props`, `screenState`, `popouts` and `utilities` after loading it.
    readonly property Component sidebarContent: Component {
        SidebarContent {
            settings: root.settings
        }
    }

    function syncBarPosition(): void {
        const position = String(root.settings.barPosition ?? "");
        if (position)
            Hooks.setValue("bar.position", root.owner, position);
        else
            Hooks.clearValue("bar.position", root.owner);
    }

    function categoryFor(w: var): string {
        if (!w)
            return "";

        const parentDir = String(w.parentDir ?? "");
        if (parentDir.includes("steamapps/workshop/content/431960"))
            return "Wallpaper Engine";

        let category = parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    // "Main" is the top-level wallpaper directory, every first-level subdirectory is a group, and
    // Wallpaper Engine workshop content is grouped separately, matching MiDnight.
    function categories(list: var): var {
        const baseDir = Paths.wallsdir;
        const cats = [];

        for (const w of list) {
            const parentDir = String(w.parentDir ?? "");
            let category;
            if (parentDir.includes("steamapps/workshop/content/431960")) {
                category = "Wallpaper Engine";
            } else if (parentDir === baseDir) {
                continue;
            } else {
                category = parentDir.slice(baseDir.length + 1);
                if (category.includes("/"))
                    category = category.slice(0, category.indexOf("/"));
            }

            if (!cats.includes(category))
                cats.push(category);
        }

        return ["Main"].concat(cats.sort());
    }

    function grouped(list: var): var {
        const baseDir = Paths.wallsdir;
        const groups = {
            "Main": []
        };

        for (const w of list) {
            const parentDir = String(w.parentDir ?? "");
            let category;
            if (parentDir.includes("steamapps/workshop/content/431960")) {
                category = "Wallpaper Engine";
            } else if (parentDir === baseDir) {
                category = "Main";
            } else {
                category = parentDir.slice(baseDir.length + 1);
                if (category.includes("/"))
                    category = category.slice(0, category.indexOf("/"));
            }

            if (!groups[category])
                groups[category] = [];
            groups[category].push(w);
        }

        return groups;
    }

    function register(): void {
        root.syncBarPosition();

        // The Nexus taskbar page lists these sides and calls back in; the choice itself stays in
        // this plugin's settings.
        Hooks.setFunction("bar.setPosition", root.owner, side => {
            const position = String(side ?? "");
            if (!root.barSides.includes(position))
                return false;
            root.settings.barPosition = position;
            return true;
        });
        Hooks.setValue("wallpapers.paused", root.owner, root.videoPaused);

        Hooks.setFunction("wallpapers.categories", root.owner, list => root.categories(list));
        Hooks.setFunction("wallpapers.grouped", root.owner, list => root.grouped(list));
        Hooks.setFunction("wallpapers.categoryFor", root.owner, w => root.categoryFor(w));

        Hooks.setFunction("launcher.appVisible", root.owner, entry => {
            if (!entry)
                return true;
            return !root.hiddenApps.includes(entry.id);
        });

        Hooks.inject("launcher.itemActions", root.owner, root.hideButton, {
            settings: root.settings
        });

        // Sidebar: tabbed notifications/AI/news body, utilities stays closed until asked for, and
        // keyboard focus for the AI input and the dashboard terminal.
        Hooks.inject("sidebar.content", root.owner, root.sidebarContent, {});
        Hooks.setValue("utilities.openWithSidebar", root.owner, false);
        Hooks.setFunction("drawers.wantsKeyboard", root.owner, state => {
            if (!state)
                return false;
            return state.sidebar === true || state.dashboard === true;
        });
    }

    // Settings changes (a new hidden app, another bar side) are reflected in every consumer.
    // Bumping the revision re-evaluates the bindings that ask the hooks.
    function refresh(): void {
        root.syncBarPosition();
        Hooks.bump();
    }

    // Re-registers on unload-safe boundaries: the entry point is recreated on plugin reload, so
    // registering once on completion is enough; only the values that live in settings need syncing.
    Component.onCompleted: root.register()

    function onUnload(): void {
        // The id reference is already torn down when the loader calls this, so the literal owner is
        // used instead of `root.owner`.
        Hooks.unregister("deeadly137/dimessentials");
    }

    readonly property Connections settingsWatch: Connections {
        target: root.settings

        function onChanged(): void {
            root.refresh();
        }
    }
}
