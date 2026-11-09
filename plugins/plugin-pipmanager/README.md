# PiP Manager

**PiP Manager** keeps Picture in Picture windows usable on a tiling compositor: it resizes them to a
fraction of the monitor and parks them in a screen quadrant instead of wherever the application
opened them. It is a port of MiDnight Shell's Picture in Picture service as a Caelestia Shell plugin.

## Features

- **Auto-align** — any window whose title contains `Picture in Picture` or `Picture-in-Picture` is
  resized to about a quarter of the monitor's short edge and moved to the configured quadrant,
  offset by the bar so it never hides under the taskbar.
- **Follow focus** — optionally move the PiP window to the monitor that has focus.
- **Drag to re-anchor** — dragging a PiP window more than 100 px snaps it to the third of the screen
  it was dropped in, without changing the saved setting.
- **Utilities card** — a **Picture in Picture** card in the utilities drawer with a pause switch, the
  current anchor and a 3×3 position grid.
- **Pause** — leave PiP windows alone without disabling the plugin.

## Requirements

- A plugin-enabled Caelestia Shell build with the `utilities-card` host: **2.5.0.r174** or newer
  (`caelestia-shell-plugins-git`).
- Hyprland, with plugin IPC enabled (the shell already needs it).

## Install

Install from Nexus → Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/caelestia-plugins.git /tmp/caelestia-plugins
cp -r /tmp/caelestia-plugins/plugins/plugin-pipmanager ~/.local/share/caelestia/plugins/deeadly137-pipmanager
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/pipmanager"]
}
```

## Use

1. Open a PiP window (Firefox, Chromium, mpv). It snaps to the configured quadrant.
2. Open Utilities and use the **Picture in Picture** card: the switch pauses or resumes auto-align,
   the 3×3 grid picks the quadrant.
3. Drag the window to another part of the screen to re-anchor it for that window only.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `position` | string | Anchor quadrant: `top left` … `bottom right`. |
| `followFocus` | bool | Move PiP windows to the focused monitor. |
| `paused` | bool | Stop moving PiP windows. The utilities card switch toggles this. |

## Plugin details

- Manifest id: `deeadly137/pipmanager`
- Display name: **PiP Manager**
- Entry points:
  - `custom` (`PipManager.qml`) — the service that watches Hyprland toplevels
  - `utilities-card` (`PipCard.qml`, name `pipmanager`)
- Settings: `settings.qml`

## License

GPL-3.0-only. See `LICENSE`.
