# MiDnight Essentials

**MiDnight Essentials** brings MiDnight's extras to Caelestia Shell as a plugin. Everything it adds is registered into the shell's plugin hooks, so disabling the plugin removes all of it and leaves the stock shell: the tabbed sidebar, the dashboard **Terminal** tab, the **Wallpaper** quick toggle, the notification and peripheral battery icons, the launcher hide buttons, the wallpaper folder groups, fullscreen wallpaper pausing, and the taskbar side.

## Features

- **Tabbed sidebar** — MiDnight's sidebar body: **Notifications**, **AI Assistant** and **News** tabs in one panel with a sliding indicator. The utilities panel no longer opens together with the sidebar; it can still be opened on its own.
- **AI assistant** — MiDnight's assistant with Ollama, OpenRouter and OpenClaw providers, model pickers, chat history and celestial mode (web search). Provider settings and keys live in this plugin instead of `shell.json`, and the chat history stays in `~/.local/share/caelestia/ai/chats.json` so existing conversations carry over.
- **Arch news** — the Arch Linux news feed on the sidebar's News tab.
- **Terminal dashboard tab** — MiDnight's terminal, ported to a `dashboard-tab` entry point. It runs commands through the shell from *Terminal shell* (default `fish`), renders ANSI colours, keeps history, resolves `cd`, and shows fish-style autocomplete.
- **Wallpaper quick toggle** — a `quick-toggle` in Utilities that prefills the launcher with `>wallpaper ` and opens it, so the wallpaper picker is one click away. The shell appends it automatically while the plugin is enabled; it is not listed in `shell.json`.
- **Bar status icons** — the notification icon (left-click opens the sidebar, right-click toggles do-not-disturb) and optional peripheral battery icons, supplied as `status-icon` entry points.
- **Launcher hide buttons** — the eye button on launcher results hides or shows an app. The list lives in this plugin's settings, never in `shell.json`.
- **Wallpaper folder groups** — the launcher's wallpaper picker shows one tab per folder under your wallpaper directory, plus **Main** and **Wallpaper Engine**, matching MiDnight.
- **Taskbar side** — Nexus → Taskbar → **Position** selects Left, Right, Top, or Bottom, and the bar, popouts, drawer margins and input masks follow the chosen edge. The choice is stored in this plugin's settings.
- **Fullscreen wallpaper pause** — video and animated wallpapers pause while a fullscreen window is visible. The shell's own **Play wallpaper** toggle stays authoritative; the plugin only asks the shell to pause.

## Requirements

- A plugin-enabled Caelestia Shell build with the plugin hook registry, the sidebar hooks and the wallpaper pause hook: **2.5.0.r130** or newer (`caelestia-shell-plugins-git`).
- `fish` (or another shell that accepts `-c COMMAND`) for the terminal tab.
- `python-playwright` (plus `playwright install firefox`) only for celestial mode.

## Install

Install from Nexus → Plugins (recommended), or clone it into the managed plugin directory:

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/plugin-dim-essentials.git ~/.local/share/caelestia/plugins/deeadly137-dimessentials
```

Enable the plugin in `~/.config/caelestia/plugins.json`:

```json
{
    "enabled": ["deeadly137/dimessentials"]
}
```

## Use

1. Open the sidebar (bar button, shortcut or screen edge); switch between **Notifications**, **AI Assistant** and **News**. The tab it opens on is configurable.
2. Open the dashboard and select the **Terminal** tab.
3. Type a command and press Enter; use Tab for shell autocomplete and the arrow keys for history.
4. Open Utilities and click the **Wallpaper** quick toggle to jump straight into the launcher's wallpaper picker.
5. Use the eye button on a launcher result to hide or show that app, and the folder tabs in the wallpaper picker to switch between wallpaper groups.
6. Change the taskbar edge in Nexus → Taskbar → **Position**.

## Settings

| Key | Type | Description |
| --- | --- | --- |
| `shell` | string | Executable used by the dashboard terminal tab. Must accept `-c COMMAND`. |
| `barPosition` | string | Screen edge the taskbar sits on: `left`, `right`, `top`, `bottom`. |
| `hiddenApps` | list | App ids hidden from the launcher by the eye buttons. |
| `showNotifications` | bool | Show the notification status icon in the bar. |
| `showPeripheralBattery` | bool | Show batteries of mice, keyboards and headsets in the bar. |
| `peripheralBatteryExcluded` | list | Device models or UPower paths to keep out of the peripheral battery icons. |
| `pauseVideoOnFullscreen` | bool | Pause video and animated wallpapers while a fullscreen window is visible. |
| `showNews` | bool | Show the **News** tab in the sidebar. |
| `initialSidebarTab` | string | Tab selected when the sidebar opens: `notifications`, `ai`, `news`. |
| `aiEnableOllama` | bool | Enable the Ollama provider. |
| `aiOllamaUrl` | string | Ollama server URL. |
| `aiDefaultOllamaModel` | string | Ollama model used when the active model is unset. |
| `aiEnableOpenRouter` | bool | Enable the OpenRouter provider. |
| `aiOpenRouterUrl` | string | OpenRouter API base URL. |
| `aiOpenRouterApiKey` | string | OpenRouter API key. |
| `aiOpenRouterModel` | string | OpenRouter model. |
| `aiEnableOpenClaw` | bool | Enable the OpenClaw provider. |
| `aiOpenClawUrl` | string | OpenClaw gateway URL. |
| `aiOpenClawToken` | string | OpenClaw gateway token. |
| `aiOpenClawModel` | string | OpenClaw model. |
| `aiEnableCelestialMode` | bool | Let the assistant search the web through `orion_search.py`. |
| `aiActiveProvider` | string | Provider the assistant starts on. |
| `aiRecentModels` | list | Recently used models, kept per provider. |
| `aiOllamaHistoryJson` | string | Legacy Ollama chat payload kept for compatibility. |

## Hooks the plugin owns

| Hook | Effect |
| --- | --- |
| `bar.position` | Overrides the bar edge (defaults to `left`). |
| `wallpapers.categories` / `wallpapers.grouped` / `wallpapers.categoryFor` | Wallpaper folder tabs and grouping. |
| `wallpapers.paused` | Masks video/animated wallpaper playback while fullscreen (the user's toggle is untouched). |
| `launcher.appVisible` | Applies `hiddenApps` to the launcher. |
| `launcher.itemActions` | The per-result hide/show button. |
| `sidebar.content` | Replaces the sidebar body with the tabbed one. |
| `utilities.openWithSidebar` | Keeps utilities closed when the sidebar opens. |
| `drawers.wantsKeyboard` | Keyboard focus for the AI input and the dashboard terminal. |

Everything is unregistered on unload, so disabling the plugin restores the stock shell.

## Plugin details

- Manifest id: `deeadly137/dimessentials`
- Display name: **MiDnight Essentials**
- Entry points:
  - `custom` (`Essentials.qml`) — registers the shell hooks, including the bar position row the
    Nexus taskbar page shows
  - `dashboard-tab` (`TerminalTab.qml`, title “Terminal”)
  - `quick-toggle` (`WallpaperToggle.qml`, name `wallpaper`)
  - `status-icon` (`NotificationsIcon.qml`, name `notifications`)
  - `status-icon` (`PeripheralBatteryIcon.qml`, name `peripheralBattery`)
- Settings: `settings.qml`
- Bundled: `orion_search.py` (celestial-mode web search)

## License

GPL-3.0-only. See `LICENSE`.
