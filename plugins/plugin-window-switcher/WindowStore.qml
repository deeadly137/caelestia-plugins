// Port of midnight-shell's window switcher source. The launcher provider renders a text list
// (title, class and workspace) because the provider contract has no preview component; Enter
// focuses the window. The list follows Hyprland's toplevel model and can be limited to the active
// workspace, like midnight-shell's setting of the same name.
import QtQuick
import Quickshell.Hyprland
import qs.services

QtObject {
    id: root

    readonly property string owner: "deeadly137/windowswitcher"

    property int revision: 0
    property var windows: []

    readonly property Connections toplevelConnections: Connections {
        function onValuesChanged(): void {
            root.refresh();
        }

        target: Hyprland.toplevels
    }

    function refresh(): void {
        const result = [];
        for (const client of Hyprland.toplevels.values) {
            const ipc = client.lastIpcObject;
            result.push({
                address: client.address,
                title: client.title || "",
                class: ipc?.class || "",
                workspace: client.workspace?.name || "",
                monitor: client.monitor?.name || "",
                wayland: client.wayland,
                mapped: ipc?.mapped ?? true,
                hidden: ipc?.hidden ?? false,
                lastIpcObject: ipc
            });
        }

        root.windows = result;
        root.revision++;
    }

    function query(text: string, activeWorkspaceOnly: bool): var {
        let results = root.windows;

        if (activeWorkspaceOnly) {
            const monitor = Hyprland.focusedMonitor;
            const special = monitor?.lastIpcObject?.specialWorkspace?.name;
            const active = special || monitor?.activeWorkspace?.name;
            if (active)
                results = results.filter(w => w.workspace === active);
        }

        const needle = String(text ?? "").toLowerCase().trim();
        if (needle.length === 0)
            return results;

        return results.filter(w => String(w.title ?? "").toLowerCase().includes(needle) || String(w.class ?? "").toLowerCase().includes(needle));
    }

    function focusCommand(address: string): string {
        return Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${address}" })` : `focuswindow address:0x${address}`;
    }

    function focus(address: string): void {
        if (!address)
            return;
        Hyprland.dispatch(root.focusCommand(address));
    }

    function onUnload(): void {
        Hooks.clearValue("windowswitcher.store", "deeadly137/windowswitcher");
    }

    Component.onCompleted: {
        Hooks.setValue("windowswitcher.store", root.owner, root);
        root.refresh();
    }
}
