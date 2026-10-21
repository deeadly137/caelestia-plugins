# Plugin examples

These are development fixtures, not installed plugins.

- `desktoppet` — a draggable pet that demonstrates the `desktop-widget` entry point and mouse input on the desktop layer.
- `livewall` — a full-screen animated wallpaper widget. It accepts a local video or animated image through its `source` setting and falls back to the bundled `loop.gif`.

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

Use only one of the two at a time when testing by hand: `livewall` covers the whole desktop and would sit above `desktoppet`.

The plugin ID is `author/name` from `manifest.json`; the directory name is only the discovery entry and does not have to match the plugin ID.
