# Plugin runtime

This directory holds the shell side of the plugin system: discovery, the manifest model, the QML
module that every plugin's files are registered into, and the loader that instantiates entry
points. Author-facing documentation lives in [`../examples/plugins/README.md`](../examples/plugins/README.md);
this file documents the runtime contract those authors can rely on.

## Layout

A plugin is a directory holding a `manifest.json` and its QML files:

```
~/.local/share/caelestia/plugins/<author>-<name>/   # installed and managed by Nexus
~/.config/caelestia/plugins/<any>/                  # hand-copied
$CAELESTIA_PLUGIN_PATH/<any>/                       # development
```

The search roots are, in order, the managed data directory, `~/.config/caelestia/plugins`, the
directories in `CAELESTIA_PLUGIN_PATH` (colon separated) and the `path` list in
`~/.config/caelestia/plugins.json`. A directory counts as a plugin when it contains
`manifest.json`. One level below a root, every subdirectory holding a manifest is a plugin too, so
a repository with several plugins can be dropped in as a whole. The plugin id is `author/name`,
lowercased.

## Manifest

```json
{
    "name": "DesktopPet",
    "author": "deeadly137",
    "version": "1.0.0",
    "description": "A draggable desktop pet.",
    "icon": "pets",
    "api": 1,
    "settings": "settings.qml",
    "entryPoints": [
        { "type": "desktop-widget", "source": "DesktopPet.qml", "properties": { "layer": "top" } }
    ]
}
```

`name`, `author` and `version` are required. `api` is the plugin API version the manifest was
written against; a manifest without it is API 1, and a newer version than the shell implements is
rejected rather than half-loaded. `settings` and `settingsUi` name files relative to the plugin
directory; `icon`, `banner` and `logo` are resolved the same way. Paths may not escape the plugin
directory.

The plugin's QML files are registered as a module whose URI is the id with `/` replaced by `.`
(`deeadly137/desktoppet` → `deeadly137.desktoppet`), one submodule per subdirectory that holds
types. Files whose base name starts with an uppercase letter become types; everything else is
still loadable as an entry point or through `Qt.createComponent`. JavaScript files are not
supported: their bindings cannot be reloaded, so they are reported as a warning and skipped.

### Entry points

| `type`           | What the shell does with it                                         |
| ---------------- | ------------------------------------------------------------------- |
| `bar-entry`      | Bar item, `properties.name` identifies it                           |
| `bar-popout`     | Popout opened by the bar entry named in `properties.entry`          |
| `status-icon`    | Icon in the bar's status area                                       |
| `quick-toggle`   | Toggle in the utilities drawer                                      |
| `dashboard-tab`  | Tab in the dashboard                                                |
| `desktop-widget` | Window on the desktop, `properties.layer` is `bottom` or `top`      |
| `page-extension` | Extra controls injected into an existing Nexus page                 |
| `custom`         | Loaded and kept alive, never shown                                  |

`properties` is passed to the loaded object as initial properties before it is completed. It is
also what the shell reads to decide where the entry point belongs (a bar entry's `name`, a
popout's `entry`, a page extension's `page`). A `custom` entry point is instantiated for as long
as the plugin is enabled and is the place for timers, sockets and background work that needs no
place in the UI.

Entry points may declare `required property SettingsObject settings`; the loader injects the
plugin's settings object when the property exists. The object may also define
`function onUnload(): void {}`, which is called before it is destroyed on a reload, on disable and
on shell shutdown. Use it to close sockets and unhook whatever the object registered elsewhere.

## Settings

`settings.qml` must be a `SettingsObject` root. It is instantiated by the shell, never declared a
singleton, and handed to entry points through the `settings` property. Rows on the generated
settings page come from `SettingMeta` attached objects inside it.

A `SettingsObject`-rooted file cannot use `Component.onCompleted` or `Component.onDestruction`:
attached objects do not exist on a plain `QObject` root, and the file then fails to load, which
leaves every entry point that requires `settings` reading a null object. Do initialization in the
property declarations instead.

Settings values live in `~/.config/caelestia/plugins.json` under `settings.<id>`, so they survive
reinstalling and disabling the plugin.

## Hot reload

Every plugin has a *generation*, a counter bumped whenever something it exposes changes. All
plugin URLs are absolute and carry it as a query parameter (`file:///…/W.qml?gen=7`). A URL is
never stored: it is derived at the moment it is needed, so bumping the generation and notifying
every live loader repoints all of them onto the new files in one synchronous fan-out. The engine
therefore compiles the file again instead of returning the unit it cached for the previous one.

What a pass does:

- Discovery stats every plugin directory. Manifests are only reparsed when the plugin is part of
  the pass, so an edit to one plugin does not reparse the others.
- Every `.qml` file has an mtime/size/hash stamp. A file whose mtime and size both match, and whose
  import context (module URI, sibling type names, other plugins' root URIs) is unchanged, is served
  from the stamp: no read, no hash, no import check. Names the watcher reported are always read
  again, because two saves inside one millisecond can produce the same mtime and size with
  different content.
- The module fingerprint covers every file's hash, the file set and every directory's URI. Only a
  plugin whose fingerprint moved gets a new generation, and the registry is updated before any
  loader is notified.
- The watch set is diffed against the watcher's current one, so passes do not drop and recreate OS
  level watches.

The watcher coalesces a burst of events (one save can touch the file, its directory and a temp
file) into a single pass after 200 ms. A file change rescans only its owning plugin; a change to
`plugins.json` takes the config path; a change under a search root is a discovery event.

Reloading is invisible where it can be:

- Visual entry points are compiled asynchronously while the current object stays live. When the
  replacement has finished compiling it is created on the GUI thread, the old object's
  `onUnload()` runs and only then is it destroyed. A failed compile leaves the last working version
  on screen and reports the error on the plugin, which Nexus shows in its Problems list.
- `custom` entry points are unloaded first, because two live copies of a background service would
  both run their timers, hooks and IPC targets even for a moment.
- A compile that lands after the plugin has moved on to a newer generation is thrown away and
  redone, so no object ever mixes imports from one generation with a URL from another.

Settings objects follow the objects that read them. A reload only rebuilds the settings object when
`settings.qml` itself changed; when it does, the old object is retired but stays alive until the
last entry point that had it injected is destroyed, so no live binding ever sees a null or freed
settings object. Nothing is freed on a timer.

Explicit reloads (`reloadPlugin(id)`) do not trust stamps: they re-read the plugin's files and give
it a new generation regardless of the fingerprint.

## What Qt cannot undo

The QML engine has no API to unregister a type. Once `deeadly137.desktoppet.ShimejiSprite` has
been registered, that name keeps resolving to the file URL it was registered with for the rest of
the process, no matter what happens to the plugin afterwards.

Consequences:

- Editing a file in place is fine: a new generation re-registers the same names against new URLs.
- Removing or renaming a file is not. The old name stays resolvable and points at a file that no
  longer exists, so QML that imports it fails to compile. The runtime detects the shrunk type set
  and reports it on the plugin, but the only fix is restarting the shell.
- Reinstalling a plugin with the same id and a different set of files therefore needs a shell
  restart. Reinstalling a plugin whose file set is unchanged does not; keeping the install
  directory stable (`~/.local/share/caelestia/plugins/<author>-<name>`) is what makes the URLs the
  same.
- Renaming a plugin renames its module too. Old imports keep resolving to the previous module and
  are reported as a warning; they work again after a restart, once the old names are gone.

Removing a plugin and its registration is deliberately not attempted: there is no way to take the
registration back, and pretending otherwise would leave silently dangling imports.
