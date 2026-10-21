pragma Singleton

import Caelestia.Plugins

PluginsBase {
    function entryPoints(type: int): list<pluginEntryPoint> {
        // Read the revision in a way the binding engine must track. A bare expression statement can
        // be optimized away and would leave desktop widgets and page extensions stale after a
        // plugin is enabled or disabled.
        return entryPointsRevision >= 0 ? __entryPoints(type) : [];
    }
}
