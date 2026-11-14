// Port of midnight-shell's Keybinds service. The list is read once and shared with the launcher
// provider. Hyprland Lua configs are parsed by the bundled `parse_keybinds.lua`, because
// `hyprctl binds -j` reports opaque `HL.Dispatcher(...)` objects for them; plain configs fall back
// to `hyprctl binds -j`. Reloading the Hyprland config refreshes the list.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

QtObject {
    id: root

    readonly property string owner: "deeadly137/keybinds"

    // Resolve the parser next to this component, dropping the plugin module's `?gen=N` query.
    readonly property string scriptPath: {
        const url = String(Qt.resolvedUrl("parse_keybinds.lua")).split("?")[0];
        return decodeURIComponent(url.replace(/^file:\/\//, ""));
    }

    property int revision: 0
    property var keybinds: []
    property bool loaded: false
    property bool loading: false
    property bool fallbackStarted: false
    property bool loadedWithLua: false
    property bool pendingReload: false

    readonly property Process luaReader: Process {
        running: false
        command: ["lua", root.scriptPath]

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = root.parseLua(text);
                if (parsed.length > 0)
                    root.finish(parsed, true);
                else
                    root.runFallback();
            }
        }

        // A missing `lua` may never produce stdout, so the fallback also runs on exit.
        onExited: {
            if (root.loading)
                root.runFallback();
        }
    }

    readonly property Process fallbackReader: Process {
        running: false
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.loading)
                    root.finish(root.parseHyprctl(text), false);
            }
        }

        onExited: {
            if (root.loading)
                root.finish([], false);
        }
    }

    readonly property Connections hyprConnections: Connections {
        function onConfigReloaded(): void {
            root.load(true);
        }

        // `Hyprland.usingLua` is false until the compositor answers, so the first load can run the
        // hyprctl fallback. Reload once the real mode is known (or if it changes).
        function onUsingLuaChanged(): void {
            if (!root.loaded || root.loadedWithLua !== Hypr.usingLua)
                root.load(true);
        }

        target: Hypr
    }

    function load(force: bool): void {
        if (root.loading) {
            if (force)
                root.pendingReload = true;
            return;
        }
        if (root.loaded && !force)
            return;

        root.keybinds = [];
        root.loaded = false;
        root.loading = true;
        root.fallbackStarted = false;
        root.pendingReload = false;

        if (Hypr.usingLua)
            root.luaReader.running = true;
        else
            root.runFallback();
    }

    function runFallback(): void {
        if (root.fallbackStarted)
            return;

        root.fallbackStarted = true;
        root.fallbackReader.running = true;
    }

    function finish(list: var, fromLua: bool): void {
        root.keybinds = Array.isArray(list) ? list : [];
        root.loaded = true;
        root.loading = false;
        root.fallbackStarted = false;
        root.loadedWithLua = fromLua;
        root.revision++;

        if (root.pendingReload) {
            root.pendingReload = false;
            root.load(true);
        }
    }

    function query(text: string): var {
        const needle = String(text ?? "").toLowerCase().trim();
        if (needle.length === 0)
            return root.keybinds;

        return root.keybinds.filter(item => String(item.bind ?? "").toLowerCase().includes(needle) || String(item.description ?? "").toLowerCase().includes(needle) || String(item.action ?? "").toLowerCase().includes(needle));
    }

    function parseLua(output: string): var {
        try {
            const parsed = JSON.parse(String(output ?? ""));
            return Array.isArray(parsed) ? parsed.filter(item => item && item.bind) : [];
        } catch (e) {
            return [];
        }
    }

    // `hyprctl binds -j` has no combined bind text, so rebuild it from the modmask and key.
    function parseHyprctl(output: string): var {
        let binds;
        try {
            binds = JSON.parse(String(output ?? ""));
        } catch (e) {
            return [];
        }

        if (!Array.isArray(binds))
            return [];

        const result = [];
        for (const b of binds) {
            const action = String(b.dispatcher ?? "") + (b.arg ? " " + b.arg : "");
            const description = b.has_description && b.description ? b.description : action;

            let keyText = String(b.key ?? "");
            if (keyText.length === 0) {
                if (!b.catch_all)
                    continue;
                keyText = "Catchall";
            }

            const mods = [];
            const mask = Number(b.modmask) || 0;
            if (mask & 64)
                mods.push("Super");
            if (mask & 8)
                mods.push("Alt");
            if (mask & 4)
                mods.push("Ctrl");
            if (mask & 1)
                mods.push("Shift");

            let bind = mods.join(" + ");
            if (bind.length > 0)
                bind += " + ";
            bind += keyText;

            result.push({
                bind: bind,
                action: action,
                description: description
            });
        }

        return result;
    }

    // The command a row runs, kept separate from `execute()` so the decision is testable.
    function commandFor(item: var): var {
        if (!item)
            return null;

        if (item.cmd)
            return ["sh", "-c", String(item.cmd)];

        if (Hypr.usingLua && item.lua)
            return ["hyprctl", "eval", String(item.lua)];

        const action = String(item.action ?? "").trim();
        if (action.length === 0)
            return null;

        if (action.startsWith("exec "))
            return ["sh", "-c", action.slice(5)];

        if (action.startsWith("global ")) {
            const name = action.slice(7).trim();
            return Hypr.usingLua ? ["hyprctl", "dispatch", `hl.dsp.global("${name}")`] : ["hyprctl", "dispatch", action];
        }

        if (action.startsWith("eval "))
            return ["hyprctl", "eval", action.slice(5)];

        // Fallback rows from a Lua compositor carry opaque dispatcher objects, not runnable text.
        if (Hypr.usingLua && /^(HL\.Dispatcher|function: )/.test(action))
            return null;

        return Hypr.usingLua ? ["hyprctl", "dispatch", `hl.dsp.${action}()`] : ["hyprctl", "dispatch", action];
    }

    function execute(item: var): void {
        const command = root.commandFor(item);
        if (command)
            Quickshell.execDetached(command);
    }

    function onUnload(): void {
        Hooks.clearValue("keybinds.store", "deeadly137/keybinds");
    }

    Component.onCompleted: {
        Hooks.setValue("keybinds.store", root.owner, root);
        root.load(false);
    }
}
