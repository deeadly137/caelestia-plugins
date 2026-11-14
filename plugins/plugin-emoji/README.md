# Emoji

**Emoji** brings MiDnight Shell's emoji picker to the Caelestia launcher. Type `emoji ` and search
the whole `caelestia emoji` list by name or character; Enter copies the emoji and closes the
launcher. Frequently used emoji rise to the top, and a favourites list keeps the ones you always
reach for at the very top.

## Features

- **Emoji search in the launcher** — type `emoji ` plus a name or tag (`fire`, `heart`, `arrow`)
  and press Enter to copy the emoji.
- **Usage ordering** — every copy increments a counter, so the emoji you use most come first.
- **Favourites** — type `efav ` to list emoji as star toggles. Enter stars or unstars an emoji and
  leaves the launcher open, so several can be marked in one go. Favourites always sort first.
- **Copy feedback** — a toast shows the copied emoji and its name.
- **Offline** — the list ships with the Caelestia CLI; no network access is needed.

## Requirements

- A plugin-enabled Caelestia Shell build with the `launcher-provider` host: **2.5.0.r171** or newer
  (`caelestia-shell-plugins-git`).
- The `caelestia` CLI with emoji data (installed by `caelestia-cli`). If the CLI is missing the
  plugin falls back to the packaged `emojis.txt`.
- `wl-clipboard` for `wl-copy`.

## Install

Install from Nexus → Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/caelestia-plugins.git /tmp/caelestia-plugins
cp -r /tmp/caelestia-plugins/plugins/plugin-emoji ~/.local/share/caelestia/plugins/deeadly137-emoji
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/emoji"]
}
```

## Use

1. Open the launcher and type `emoji `, then part of an emoji name.
2. Press Enter on a result to copy it and close the launcher.
3. Type `efav ` instead to star or unstar emoji; the launcher stays open while you do.

With an empty query (`emoji ` alone) the list starts with your favourites, then the emoji you use
most, then the rest of the list in file order.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `trigger` | string | Prefix for the copy list. Default `emoji ` (keep the trailing space). |
| `favouriteTrigger` | string | Prefix for the favourite toggles. Default `efav `. |
| `limit` | int | Maximum number of emoji shown per query. |

Favourites and usage counters are stored in `$XDG_STATE_HOME/caelestia/emoji/state.json`, not in
the plugin settings, so the generated settings page stays free of array and map rows.

## Plugin details

- Manifest id: `deeadly137/emoji`
- Display name: **Emoji**
- Entry points:
  - `custom` (`EmojiStore.qml`) — the emoji list, usage counters and favourites file
  - `launcher-provider` (`EmojiProvider.qml`, name `emoji`) — copy results
  - `launcher-provider` (`EmojiProvider.qml`, name `emoji-favourites`, mode `favourite`) — star
    toggles
- Settings: `settings.qml`

## License

GPL-3.0-only. See `LICENSE`.
