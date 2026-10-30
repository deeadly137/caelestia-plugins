# Plugins

First-party plugins for the Caelestia plugin-enabled shell. They are developed here, but they are
**not installed with the shell**: the AUR package only installs the shell itself (`assets`,
`components`, `daemons`, `modules`, `services`, `utils`). Each plugin is installed separately from
Nexus → Plugins.

`index.json` is the plugin index the shell fetches. Each entry points at this same repository and
selects a subdirectory with `path`, so the installer shallow-clones the repository and moves only
that directory into `~/.local/share/caelestia/plugins/<id>`.

| Directory | Plugin id | Summary |
| --- | --- | --- |
| `plugin-desktop-lyrics` | `deeadly137/desktoplyrics` | Synced lyrics over the desktop |
| `plugin-desktop-pet` | `deeadly137/desktoppet` | Shimeji desktop pet |
| `plugin-livewallpaper` | `deeadly137/livewall` | Video / Wallpaper Engine wallpapers |
| `plugin-nebula-widgets` | `deeadly137/nebulawidgets` | Nebula-style desktop widgets |
| `plugin-wallhaven` | `deeadly137/wallhaven` | Wallhaven browser/downloader |
| `plugin-dim-essentials` | `deeadly137/dimessentials` | MiDnight features (sidebar, terminal, bar side, …) |

Each directory is a complete plugin: `manifest.json`, `settings.qml`, its entry point sources and
an optional `LICENSE`. Keep them self-contained; the shell loads a plugin directory, never the
repository around it.
