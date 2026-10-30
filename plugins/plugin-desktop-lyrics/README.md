# Desktop Lyrics

Synced lyrics floating over the desktop, with midnight-shell's lyrics options.

The plugin declares two `desktop-widget` entry points from the same source: `layer: bottom` for
the desktop copy and `layer: top` for the above-window copy. Only the copy that matches the
**Overlay** setting is alive, so exactly one lyrics surface exists per screen. Both are
click-through. It shares the shell's lyrics service, so the dashboard's lyric view and this overlay
can be open at the same time.

## Usage

- Start playing something with synced lyrics (LRCLIB/NetEase, whatever the shell's media section
  uses). The lyrics fade in on their own.
- The current line is highlighted; the previous and next lines fade out above and below.
- Configure everything in **Nexus → System → Plugins → Desktop Lyrics**:
  - **Overlay** — draw on top of normal windows instead of on the desktop.
  - **Hide on fullscreen** / **Hide on tiled windows** — both on by default, like midnight-shell.
  - **Scale** — 0.5 to 3.
  - **Position** — nine-grid; defaults to bottom center.
  - **Invert colours** — for light wallpapers.
  - **Background** group — off by default, with opacity and blur.
  - **Shadow** group — on by default, with opacity and blur.

The box is 350x180 scaled by **Scale**, the same as midnight-shell, and its margins clear the
taskbar on whichever edge it sits on (the taskbar position comes from the shell's `bar.position`
hook, so it also follows a plugin-managed bar edge).

Every screen gets its own copy. The lyrics take no pointer input, so clicking through them works
normally.

## Requirements

- A plugin-enabled Caelestia Shell build with `desktop-widget` entry points and own-property
  injection (2.5.0.r118 or newer), such as `caelestia-shell-plugins-git`.
- A player exposing MPRIS metadata and synced lyrics (the shell's built-in lyric providers).

## Install

From **Nexus → System → Plugins → Browse** (recommended), or manually:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone --depth 1 https://github.com/deeadly137/caelestia-plugins.git /tmp/caelestia-plugins
mv /tmp/caelestia-plugins/plugins/plugin-desktop-lyrics ~/.local/share/caelestia/plugins/desktop-lyrics
rm -rf /tmp/caelestia-plugins
```

Then enable `deeadly137/desktoplyrics` in `~/.config/caelestia/plugins.json` (the Plugins page in
Nexus does this for you).

## License

GPL-3.0, same as the shell.
