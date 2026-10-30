# Desktop Pet

A port of midnight-shell's Shimeji desktop pet for Caelestia Shell. The pet walks, climbs the screen edges, falls, sits, and can be picked up and dragged. It lives on the top layer so it stays above windows, while its input surface is limited to the sprite rectangles.

## Requirements

- A plugin-enabled Caelestia Shell build with the `desktop-widget` entry point and top-layer support, such as `caelestia-shell-plugins-git`.
- A standard 46-frame Shimeji pack. A Pusheen pack is bundled under `assets/pusheen`.

## Install

Install from Nexus > Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/plugin-desktop-pet.git ~/.local/share/caelestia/plugins/plugin-desktop-pet
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/desktoppet"]
}
```

## Settings

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `path` | string | `assets/pusheen` | Directory or `.zip` containing the frame pack. Relative paths resolve against the plugin directory. |
| `count` | int | `1` | Number of pets on each screen (1-8). |
| `scale` | real | `1` | Size multiplier for the 128 px frame pack (0.5-2). |
| `autoHide` | bool | `false` | Only show pets while the active workspace has no tiled windows. |

## Frame pack layout

The pack must contain files named `shime1.png` through `shime46.png` (or the equivalent frames from another standard Shimeji pack) in a single directory. The frame semantics are the same as midnight-shell:

- Idle/stand, walk, run, sit, and fall frames
- Wall climb frames for both sides
- Ceiling frames
- Drag/pick-up frames

If the pack is a `.zip`, the plugin extracts it to the same directory name without the extension when it first loads it.

## Behavior

- Physics, state transitions, and frame selection come from midnight-shell's `ShimejiSprite.qml`.
- The plugin root exposes an `inputMask` built from each sprite's current rectangle, so clicks outside the pet pass through to windows and the desktop.
- The top-layer host sets `WlrKeyboardFocus.None`; the pet never takes keyboard focus.
- When `autoHide` hides the pet, the input mask is emptied as well as the item hidden.

## Plugin details

- Manifest id: `deeadly137/desktoppet`
- Entry point: `desktop-widget` with `properties.layer = "top"`
- Source: `DesktopPet.qml`
- Sprite implementation: `ShimejiSprite.qml`
- Settings: `settings.qml`

## License

GPL-3.0-only. See `LICENSE`.
