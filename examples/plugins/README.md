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

## Card metadata

The browser reads display metadata from the plugin's own `manifest.json`, not from the public index. Optional fields used by the plugin cards:

```json
{
    "tags": ["desktop", "widget"],
    "banner": "preview.png",
    "logo": "logo.png"
}
```

`banner` and `logo` may be relative to the manifest or absolute URLs. The banner is rendered in a 16:9 frame with aspect-preserving cropping; the logo is drawn as a small badge over it. `image` is accepted as a legacy alias for `banner`. The public index only stores `{ "id", "repo" }` entries.
