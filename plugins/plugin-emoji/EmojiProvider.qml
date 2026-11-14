// Launcher results for the emoji list. The same file backs two entry points: `copy` inserts the
// emoji and records the usage, `favourite` toggles the star and keeps the launcher open.
import QtQuick
import Quickshell
import Caelestia
import Caelestia.Plugins
import qs.services

QtObject {
    id: root

    required property SettingsObject settings

    // Injected from the manifest: "copy" (default) or "favourite".
    property string mode: "copy"

    readonly property var store: Hooks.value("emoji.store")
    readonly property string trigger: root.mode === "favourite" ? (root.settings?.favouriteTrigger ?? "efav ") : (root.settings?.trigger ?? "emoji ")
    readonly property int limit: Math.max(1, Number(root.settings?.limit) || 20)

    function query(text: string): var {
        const store = root.store;
        if (!store || !Array.isArray(store.sortedItems))
            return [];

        const needle = String(text ?? "").trim().toLowerCase();
        const matches = [];

        for (const item of store.sortedItems) {
            if (needle.length > 0 && item.name.toLowerCase().indexOf(needle) < 0 && item.char.toLowerCase().indexOf(needle) < 0)
                continue;
            matches.push(item);
            if (matches.length >= root.limit)
                break;
        }

        const favourites = new Set(Array.isArray(store.favourites) ? store.favourites.map(String) : []);
        return matches.map(item => root.result(item, favourites.has(item.char)));
    }

    function result(item: var, favourite: bool): var {
        const label = `${item.char}  ${item.name}`;

        if (root.mode === "favourite") {
            return {
                name: (favourite ? "★ " : "☆ ") + label,
                description: favourite ? "Remove from favourites" : "Add to favourites",
                icon: favourite ? "star" : "star_border",
                keepOpen: true,
                activate: () => root.store?.toggleFavourite(item.char)
            };
        }

        return {
            name: label,
            description: "Copy emoji",
            icon: "emoji_emotions",
            activate: () => root.copy(item)
        };
    }

    function copy(item: var): void {
        Quickshell.execDetached(["wl-copy", item.char]);
        root.store?.recordUsage(item.char);
        Toaster.toast("Copied to clipboard", `${item.char} ${item.name}`, "emoji_emotions");
    }
}
