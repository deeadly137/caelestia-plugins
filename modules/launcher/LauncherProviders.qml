pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Plugins

// Hosts `launcher-provider` entry points. A provider is a plain object with a
// `function query(text: string): var` that returns an array of result objects. Results are shown
// after the stock app results, unless the provider declared a `trigger` prefix that matched, in
// which case they are shown first so Enter runs the provider.
//
// The host lives with the launcher, so providers are only loaded while the launcher is open.
Item {
    id: root

    // Bumped when a provider finishes loading, so bindings that call `query()` re-evaluate.
    property int revision: 0

    readonly property var providers: {
        CUtils.dependency(Plugins.entryPointsRevision);
        return Array.from(Plugins.entryPoints(EntryPointType.LauncherProvider)).slice().sort((a, b) => {
            const byOrder = (a.properties.order ?? 100) - (b.properties.order ?? 100);
            return byOrder !== 0 ? byOrder : (a.properties.name ?? "").localeCompare(b.properties.name ?? "");
        });
    }

    function query(text: string): var {
        // Track the registry so adding/removing a provider re-evaluates the caller's binding.
        CUtils.dependency(Plugins.entryPointsRevision);

        const results = [];
        for (let i = 0; i < providerRepeater.count; i++) {
            const loader = providerRepeater.itemAt(i);
            const provider = loader?.item;
            if (!provider || typeof provider.query !== "function")
                continue;

            // A provider may compute its trigger, but usually it is static and lives in the
            // manifest properties.
            const configured = loader?.entryPoint?.properties ?? {};
            const trigger = String(provider.trigger ?? configured.trigger ?? "");
            let queryText = text;
            if (trigger.length > 0) {
                if (!text.toLowerCase().startsWith(trigger.toLowerCase()))
                    continue;
                queryText = text.slice(trigger.length).trim();
                if (queryText.length === 0)
                    continue;
            }

            let items;
            try {
                items = provider.query(queryText);
            } catch (e) {
                console.warn(logCat, "Provider for", loader?.entryPoint?.plugin?.name, "threw:", e);
                continue;
            }

            if (!Array.isArray(items))
                continue;

            const limit = Math.max(0, Number(provider.limit ?? configured.limit ?? 5));
            for (const item of items.slice(0, limit)) {
                if (!item || typeof item !== "object" || !item.name)
                    continue;
                results.push(Object.assign({}, item, {
                    pluginLauncher: true,
                    pluginTrigger: trigger.length > 0
                }));
            }
        }
        return results;
    }

    visible: false
    width: 0
    height: 0

    Repeater {
        id: providerRepeater

        model: root.providers

        delegate: EntryPointLoader {
            required property var modelData

            entryPoint: modelData

            onItemChanged: root.revision++
            onLoaded: root.revision++
        }
    }

    LoggingCategory {
        id: logCat

        name: "caelestia.launcher.providers"
        defaultLogLevel: LoggingCategory.Info
    }
}
