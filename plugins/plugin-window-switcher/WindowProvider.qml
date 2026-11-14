// Launcher results for the window list. Search matches the window title and class; Enter focuses
// the window and closes the launcher.
import QtQuick
import Caelestia.Plugins
import qs.services
import qs.utils

QtObject {
    id: root

    required property SettingsObject settings

    readonly property var store: Hooks.value("windowswitcher.store")
    readonly property string trigger: root.settings?.trigger ?? "windows "
    readonly property int limit: Math.max(1, Number(root.settings?.limit) || 20)

    function query(text: string): var {
        const store = root.store;
        if (!store)
            return [];

        const activeOnly = root.settings?.activeWorkspaceOnly ?? true;
        const matches = store.query(String(text ?? ""), activeOnly).filter(item => item.mapped !== false && !item.hidden);
        return matches.slice(0, root.limit).map(item => root.result(item));
    }

    function result(item: var): var {
        return {
            name: item.title || item.class || "Untitled window",
            description: root.describe(item),
            icon: Icons.getAppCategoryIcon(item.class || "", "window"),
            activate: () => root.store?.focus(item.address)
        };
    }

    function describe(item: var): string {
        const parts = [];
        if (item.class)
            parts.push(item.class);
        if (item.workspace)
            parts.push(`workspace ${item.workspace}`);
        return parts.join(" · ");
    }

    Component.onCompleted: if (root.store)
        root.store.refresh()
}
