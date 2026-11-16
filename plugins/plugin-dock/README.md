# Dock

**Dock** brings MiDnight Shell's application dock to the Caelestia bar. Pinned apps come first,
running windows are grouped by application, and each icon shows a dot per open window. Click an
icon to focus or launch the app, hover it for live window previews, or right-click for pin, new
window and end-task actions.

## Features

- **Pinned apps and running windows** — pins come from the launcher's favourite apps
  (`GlobalConfig.launcher.favouriteApps`), so starring an app in the launcher also pins it here.
  Running apps without a pin are appended automatically.
- **Focus and launch** — clicking an app with windows focuses its first window; clicking a pinned
  app without windows launches it and shows a spinner until the window appears.
- **Hover previews** — hovering an icon opens a card per window with a live screencopy preview;
  click the preview to focus that window or the close button to end it. The card also exposes
  media controls when the app owns the active MPRIS player.
- **Context menu** — right-click to pin/unpin the app, open a new window, or end all of its tasks.
- **Drag to reorder** — drag icons along the bar; the new order is written back to the pinned list.
- **Bar-aware** — follows the bar's edge (top, bottom, left or right), including the vertical
  layout, and does not push the notifications/sidebar panels aside while its popouts are open.

## Requirements

- A plugin-enabled Caelestia Shell build with the `bar-entry`/`bar-popout` dock host and the
  `handleHover` entry hook: **2.5.0.r191** or newer (`caelestia-shell-plugins-git`).
- Hyprland, with plugin IPC enabled (the shell already needs it).
- `wl-clipboard` is **not** needed; window previews use screencopy, which the shell already uses.

## Install

Install from Nexus → Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/caelestia-plugins.git /tmp/caelestia-plugins
cp -r /tmp/caelestia-plugins/plugins/plugin-dock ~/.local/share/caelestia/plugins/deeadly137-dock
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/dock"]
}
```

### Placing the dock

A plugin bar entry is appended to the **end** section of the bar unless a section already lists its
id. To get a centred dock, add it to the `center` section in `~/.config/caelestia/shell.json`:

```json
{
    "bar": {
        "entries": {
            "center": {
                "values": [
                    { "id": "activeWindow", "enabled": true },
                    { "id": "dock", "enabled": true }
                ]
            }
        }
    }
}
```

The id is the entry point name from the manifest (`dock`). Placing it in `start` or `end` also
works; the dock adapts to the bar edge either way.

## Use

1. Pin apps from the launcher (star icon) or from the dock's right-click menu.
2. Click a dock icon to focus or launch the app.
3. Hover an icon to preview its windows; click a preview to focus that window.
4. Right-click an icon to pin/unpin, open a new window or end the app's tasks.
5. Drag icons to reorder them.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `recolourIcons` | bool | Tint icons with the secondary theme colour instead of showing them as-is. |
| `showPreviews` | bool | Show live window previews in the hover popout. Off gives a lighter title-only card. |

Pinned apps live in the shell's launcher config (`GlobalConfig.launcher.favouriteApps`), not in the
plugin settings, because a list setting would render as an editable text row.

## Plugin details

- Manifest id: `deeadly137/dock`
- Display name: **Dock**
- Entry points:
  - `bar-entry` (`Dock.qml`, name `dock`) — the dock itself
  - `bar-popout` (`DockHover.qml`, entry `dockhover`) — per-window hover previews
  - `bar-popout` (`DockContext.qml`, entry `dockcontext`) — pin / new window / end task
- Settings: `settings.qml`

The hover and context popouts use the reserved `dockhover`/`dockcontext` names. The dock sets
`popouts.dockModel` before opening them, so they read the app the pointer is over without sharing
any state with the dock item.

## Differences from MiDnight Shell

- The dock is a plugin bar entry rather than a built-in bar component, so it is placed through
  `bar.entries` and configured in Nexus → Plugins instead of the bar settings.
- `bar.dock.monitorCenter` is not ported: the dock sits wherever its bar section is anchored, so a
  centred dock is a matter of putting the entry in the `center` section.
- The window-info chevron in the hover card is not ported, because the shell's window-info popout
  always describes the focused window rather than the clicked one.

## License

GPL-3.0-only. See `LICENSE`.
