# Keybinds

**Keybinds** brings MiDnight Shell's keybind browser to the Caelestia launcher. Type `keybinds `
and search the active Hyprland bindings by key combination, friendly description or raw action.
Enter runs the binding.

## Features

- **Searchable keybind list** — type `keybinds ` and part of a key combination (`Super + R`), a
  description (`launcher`, `screenshot`, `workspace`) or a dispatcher.
- **Friendly names** — Lua configs are parsed by the bundled `parse_keybinds.lua`, so rows show
  descriptions such as *Toggle Launcher* and *Screenshot Region* instead of dispatcher internals.
- **Run on Enter** — executing a row dispatches the binding through Hyprland: `exec` entries run
  their command, Lua entries are evaluated with `hyprctl eval`, everything else is dispatched.
- **Live refresh** — reloading the Hyprland config rebuilds the list.
- **Fallback** — non-Lua configs (and systems without `lua`) use `hyprctl binds -j` and format the
  bind text from the modifier mask.

## Requirements

- A plugin-enabled Caelestia Shell build with the `launcher-provider` host: **2.5.0.r171** or newer
  (`caelestia-shell-plugins-git`).
- Hyprland. `hyprctl` is used to run bindings and as the fallback source.
- `lua` (5.x) for the richer Lua-config parsing. Without it the plugin falls back to
  `hyprctl binds -j`.

## Install

Install from Nexus → Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/caelestia-plugins.git /tmp/caelestia-plugins
cp -r /tmp/caelestia-plugins/plugins/plugin-keybinds ~/.local/share/caelestia/plugins/deeadly137-keybinds
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/keybinds"]
}
```

## Use

1. Open the launcher and type `keybinds `.
2. Narrow the list with a key combination, a description or a dispatcher.
3. Press Enter on a row to run that binding.

The list is read when the shell starts and rebuilt after a Hyprland config reload.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `trigger` | string | Prefix for the list. Default `keybinds ` (keep the trailing space). |
| `limit` | int | Maximum number of keybinds shown per query. |

## Plugin details

- Manifest id: `deeadly137/keybinds`
- Display name: **Keybinds**
- Entry points:
  - `custom` (`KeybindStore.qml`) — loads the list, watches for config reloads, runs bindings
  - `launcher-provider` (`KeybindProvider.qml`, name `keybinds`) — search results
- Bundled asset: `parse_keybinds.lua`
- Settings: `settings.qml`

## License

GPL-3.0-only. See `LICENSE`.
