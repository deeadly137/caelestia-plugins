# Plugin examples

These are development fixtures, not installed plugins. Their canonical public repositories are:

- [plugin-desktop-pet](https://github.com/deeadly137/plugin-desktop-pet) — a Shimeji port on the top layer. It demonstrates `desktop-widget` with `properties.layer: "top"` and a per-instance `inputMask`.
- [plugin-livewallpaper](https://github.com/deeadly137/plugin-livewallpaper) — adds controls to Nexus > Wallpaper & style through the `page-extension` entry point and applies videos through the shell's normal background renderer. GIF/WebP files use a desktop-widget overlay.

## Try them

Point the shell at this directory and enable the plugin you want:

```sh
export CAELESTIA_PLUGIN_PATH="$PWD/examples/plugins"
```

```json
{
    "enabled": ["deeadly137/desktoppet"],
    "path": [],
    "settings": {}
}
```

The fixtures are intentionally small. Use only one of the two at a time when testing by hand: the example `livewall` covers the whole desktop and would sit above `desktoppet`.

The plugin ID is `author/name` from `manifest.json`; the directory name is only the discovery entry and does not have to match the plugin ID.
