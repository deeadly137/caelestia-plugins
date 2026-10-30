# Wallhaven

Search [Wallhaven](https://wallhaven.cc) from Nexus and set the result as your wallpaper, with no
browser round trip.

The plugin uses the `page-extension` entry point. **Nexus → Wallpaper & style → Wallhaven** opens a
sub-page next to *Widgets*, with a search field, a shuffle button, a results grid and a preview for
the selected wallpaper.

## Usage

- Search for a phrase, or hit shuffle for a random result.
- Click a thumbnail to preview it; **Set as wallpaper** downloads the full image to your wallpapers
  folder and applies it through `caelestia wallpaper`.
- Use **Load more** to page through results.
- Configure categories, purity, sorting, minimum resolution and an API key in
  **Nexus → System → Plugins → Wallhaven**.

Sketchy and NSFW results require a Wallhaven API key (account settings → API key). Without a key
those filters are ignored. The API key is only sent to `wallhaven.cc`.

## Requirements

- A plugin-enabled Caelestia Shell build with multi-slot `page-extension` sub-pages
  (2.5.0.r117 or newer), such as `caelestia-shell-plugins-git`.
- `curl` for downloads (already part of the shell's dependencies).

## Install

```sh
mkdir -p ~/.local/share/caelestia/plugins
git clone https://github.com/deeadly137/plugin-wallhaven.git \
  ~/.local/share/caelestia/plugins/wallhaven
```

Then enable `deeadly137/wallhaven` in `~/.config/caelestia/plugins.json` (the Plugins page in Nexus
does this for you) and open **Wallpaper & style**.

## License

GPL-3.0, same as the shell.
