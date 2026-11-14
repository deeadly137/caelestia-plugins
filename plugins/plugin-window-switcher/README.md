# Window Switcher

**Window Switcher** brings MiDnight Shell's window switcher to the Caelestia launcher as a
searchable list. Type `windows ` and search by window title or application class; Enter focuses the
window. It follows the focused workspace by default, like the midnight setting it is ported from.

## Features

- **Search open windows** — type `windows ` plus part of a title or class (`firefox`, `kitty`,
  `notes`) and press Enter to focus the match.
- **Active workspace filter** — by default only windows on the focused workspace are listed; a
  focused special workspace is handled too. Turn it off to search every workspace.
- **Live list** — the list follows Hyprland's toplevel model, so opening and closing windows updates
  it without reopening the launcher.
- **App icons** — each row uses the same category icon rules as the bar.

The midnight version is a carousel with live window previews. The `launcher-provider` contract
renders text rows only, so this port shows the title, class and workspace instead of a screencopy
thumbnail; focusing a window works the same.

## Requirements

- A plugin-enabled Caelestia Shell build with the `launcher-provider` host: **2.5.0.r171** or newer
  (`caelestia-shell-plugins-git`).
- Hyprland, with plugin IPC enabled (the shell already needs it).

## Install

Install from Nexus → Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/caelestia-plugins.git /tmp/caelestia-plugins
cp -r /tmp/caelestia-plugins/plugins/plugin-window-switcher ~/.local/share/caelestia/plugins/deeadly137-windowswitcher
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/windowswitcher"]
}
```

## Use

1. Open the launcher and type `windows `.
2. Narrow the list with part of a window title or class.
3. Press Enter on a row to focus that window; the launcher closes.

Windows that are hidden or not mapped are skipped, since they cannot be focused usefully.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `trigger` | string | Prefix for the list. Default `windows ` (keep the trailing space). |
| `activeWorkspaceOnly` | bool | List only windows on the focused workspace. |
| `limit` | int | Maximum number of windows shown per query. |

## Plugin details

- Manifest id: `deeadly137/windowswitcher`
- Display name: **Window Switcher**
- Entry points:
  - `custom` (`WindowStore.qml`) — tracks the toplevel list and focuses windows
  - `launcher-provider` (`WindowProvider.qml`, name `windows`) — search results
- Settings: `settings.qml`

## License

GPL-3.0-only. See `LICENSE`.
