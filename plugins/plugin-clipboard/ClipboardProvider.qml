// Launcher results for the clipboard history. The same file backs two entry points: `copy` lists
// clips and copies the chosen one, `favourite` toggles the star and keeps the launcher open.
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

    readonly property var store: Hooks.value("clipboard.store")
    readonly property string trigger: root.mode === "favourite" ? (root.settings?.favouriteTrigger ?? "cfav ") : (root.settings?.trigger ?? "clip ")
    readonly property int limit: Math.max(1, Number(root.settings?.historySize) || 20)

    function query(text: string): var {
        const store = root.store;
        if (!store)
            return [];

        store.refresh(false);

        const needle = String(text ?? "").trim().toLowerCase();
        const favourites = new Set(Array.isArray(store.favouriteClips) ? store.favouriteClips.map(String) : []);
        const items = Array.isArray(store.items) ? store.items : [];
        const favs = [];
        const rest = [];

        for (const item of items) {
            if (item.isImage && !(root.settings?.showImages ?? true))
                continue;
            if (needle.length > 0 && item.preview.toLowerCase().indexOf(needle) < 0)
                continue;

            if (favourites.has(String(item.id)))
                favs.push(item);
            else
                rest.push(item);
        }

        return favs.concat(rest).slice(0, root.limit).map(item => root.result(item, favourites.has(String(item.id))));
    }

    function result(item: var, favourite: bool): var {
        const label = root.label(item);

        if (root.mode === "favourite") {
            return {
                name: (favourite ? "★ " : "☆ ") + label,
                description: favourite ? "Remove from favourites" : "Add to favourites",
                icon: favourite ? "star" : "star_border",
                keepOpen: true,
                activate: () => root.store?.toggleFavourite(item.id)
            };
        }

        return {
            name: label,
            description: root.describe(item),
            icon: item.isImage ? "image" : "content_paste",
            activate: () => root.copy(item)
        };
    }

    function label(item: var): string {
        if (item.isImage) {
            const dims = String(item.preview).match(/(\d+)x(\d+)/);
            return dims ? `Image ${dims[1]}×${dims[2]}` : "Image";
        }

        const text = String(item.preview).replace(/\s+/g, " ").trim();
        return text.length > 80 ? text.slice(0, 79) + "…" : text;
    }

    function describe(item: var): string {
        if (item.isImage) {
            const meta = String(item.preview).replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "");
            return meta.length > 0 ? `Clipboard image (${meta})` : "Clipboard image";
        }

        return "Clipboard entry";
    }

    function copy(item: var): void {
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${Number(item.id)} | wl-copy`]);
        Toaster.toast("Copied to clipboard", root.label(item), "content_paste");
    }

    // The launcher loads providers again every time it opens, so refresh once per open. The store
    // keeps the listing between opens; `force` makes it current after a copy elsewhere.
    Component.onCompleted: if (root.store)
        root.store.refresh(true)

    onStoreChanged: if (root.store)
        root.store.refresh(true)
}
