pragma Singleton

import Caelestia
import Caelestia.Plugins

PluginsBase {
    function entryPoints(type: int): list<pluginEntryPoint> {
        // For reactivity: without this, desktop widgets and page extensions stay stale after a
        // plugin is enabled or disabled.
        CUtils.dependency(entryPointsRevision);
        return __entryPoints(type);
    }
}
