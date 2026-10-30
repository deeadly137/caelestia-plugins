# Live Wallpaper

A Caelestia Shell plugin for video, animated-image and Wallpaper Engine wallpapers. It adds a **Live wallpaper** section to Nexus > Wallpaper & style and uses the shell's normal background renderer for videos, a desktop overlay for GIF/WebP, and `linux-wallpaperengine` for Wallpaper Engine scenes.

## Requirements

- A plugin-enabled Caelestia Shell build with `page-extension`, `desktop-widget` and `custom` entry points. The shared playback state and external wallpaper provider used by this version need **2.5.0.r130** (`caelestia-shell-plugins-git`) or newer.
- `ffmpeg`/`ffprobe` for the `caelestia wallpaper` CLI that generates thumbnails and validates video files.
- Qt Multimedia support for video playback (included with the shell dependencies).
- `linux-wallpaperengine` for Wallpaper Engine scenes.

## Install

Install from Nexus > Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/plugin-livewallpaper.git ~/.local/share/caelestia/plugins/plugin-livewallpaper
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/livewall"]
}
```

## Use

1. Open Nexus > Wallpaper & style.
2. In **Live wallpaper**, choose a video, GIF, or animated WebP with **Video or animated image**.
3. Use **Play wallpaper** to pause or resume playback.
4. For a Wallpaper Engine scene, use **Wallpaper Engine → Scene** and pick the scene's `project.json` (the file inside the Workshop item directory). The scene starts on every monitor through `linux-wallpaperengine --screen-root <monitor> --layer background`, and the shell background yields to the engine surface. The scene's preview image is applied as the regular wallpaper so the colour scheme stays in sync.
5. **Mute engine audio** starts the engine with `--silent`; the engine volume slider is in the plugin's settings.

Videos are passed to `Wallpapers.setWallpaper()`, which is the same path used by the normal wallpaper picker. The shell renders them through its built-in `WallpaperImpl`/`Visual` video path. GIF/WebP files additionally use an `AnimatedImage` desktop overlay because the built-in renderer only keeps the first frame for those formats.

While a fullscreen window is visible, the **Pause on fullscreen** switch in the MiDnight Essentials plugin pauses videos and the animated overlay together. Wallpaper Engine scenes keep running; stop them with **Clear scene**.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `source` | string | Absolute path to the current video/GIF/WebP. The page extension writes this when you pick a file. |
| `engineSource` | string | Wallpaper Engine scene directory (the folder containing `project.json`). |
| `engineSilent` | bool | Pass `--silent` to `linux-wallpaperengine`. |
| `engineVolume` | real | Engine volume, 0 to 1. |

The source and engine scene are persisted in `plugins.json`, and the normal wallpaper path is persisted by the CLI, so the live wallpaper survives shell restarts.

## Plugin details

- Manifest id: `deeadly137/livewall`
- Entry points:
  - `page-extension` (`WallpaperSettings.qml`, page `wallpaper`)
  - `desktop-widget` (`LiveWallpaper.qml`, animated-image overlay)
  - `custom` (`EngineProvider.qml`, Wallpaper Engine process per monitor)
- Settings: `settings.qml`

## License

GPL-3.0-only. See `LICENSE`.
