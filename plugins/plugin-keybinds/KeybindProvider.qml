// Launcher results for the keybind list. Search matches the bind text, the friendly description
// and the raw action, and Enter runs the binding.
import QtQuick
import Caelestia.Plugins
import qs.services

QtObject {
    id: root

    required property SettingsObject settings

    readonly property var store: Hooks.value("keybinds.store")
    readonly property string trigger: root.settings?.trigger ?? "keybinds "
    readonly property int limit: Math.max(1, Number(root.settings?.limit) || 100)

    function query(text: string): var {
        const store = root.store;
        if (!store)
            return [];

        store.load(false);

        const matches = store.query(String(text ?? ""));
        return matches.slice(0, root.limit).map(item => root.result(item));
    }

    function result(item: var): var {
        return {
            name: item.bind || "No keybind",
            description: item.description || item.action || "",
            icon: "keyboard",
            activate: () => root.store?.execute(item)
        };
    }
}
