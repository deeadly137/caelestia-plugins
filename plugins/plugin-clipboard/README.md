# Clipboard

**Clipboard** brings MiDnight Shell's clipboard history to the Caelestia launcher. It reads the
same `cliphist` history as the rest of the desktop, copies a chosen entry back with `wl-copy`, and
keeps a favourites list so frequently used snippets stay on top.

## Features

- **History in the launcher** — type `clip ` and pick an entry. Enter copies it and closes the
  launcher.
- **Favourites** — type `cfav ` to list clips as star toggles. Enter stars or unstars a clip and
  leaves the launcher open, so several can be marked in one go. Starred clips sort first in both
  lists.
- **Search** — the text after the trigger filters the history by preview, case-insensitively.
- **Images** — binary entries are listed with their dimensions and copied as images. Turn them off
  in settings if the history is text-only.
- **Toasts** — copying shows the usual shell toast with the copied preview.

## Requirements

- A plugin-enabled Caelestia Shell build with the `launcher-provider` host: **2.5.0.r171** or newer
  (`caelestia-shell-plugins-git`).
- [`cliphist`](https://github.com/sentriz/cliphist) with a running `wl-paste --watch cliphist store`
  (the shell does not start the watcher).
- `wl-clipboard` for `wl-copy`.

## Install

Install from Nexus → Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/caelestia-plugins.git /tmp/caelestia-plugins
cp -r /tmp/caelestia-plugins/plugins/plugin-clipboard ~/.local/share/caelestia/plugins/deeadly137-clipboard
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/clipboard"]
}
```

## Use

1. Open the launcher and type `clip `, then part of the text you copied.
2. Press Enter on a result to copy it back and close the launcher.
3. Type `cfav ` instead to star or unstar clips; the launcher stays open while you do.

The history itself is owned by `cliphist`; this plugin only reads and decodes it.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `trigger` | string | Prefix for the copy list. Default `clip ` (keep the trailing space). |
| `favouriteTrigger` | string | Prefix for the favourite toggles. Default `cfav `. |
| `historySize` | int | Maximum number of clips shown per query. |
| `showImages` | bool | Include binary (image) clipboard entries. |

Favourites are stored in `$XDG_STATE_HOME/caelestia/clipboard/favourites.json`, not in the plugin
settings, so the generated settings page stays free of array rows.

## Plugin details

- Manifest id: `deeadly137/clipboard`
- Display name: **Clipboard**
- Entry points:
  - `custom` (`ClipboardStore.qml`) — one shared `cliphist list` and the favourites file
  - `launcher-provider` (`ClipboardProvider.qml`, name `clipboard`) — copy results
  - `launcher-provider` (`ClipboardProvider.qml`, name `clipboard-favourites`, mode `favourite`) —
    star toggles
- Settings: `settings.qml`

## License

GPL-3.0-only. See `LICENSE`.
