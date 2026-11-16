import Caelestia.Plugins

SettingsObject {
    property bool recolourIcons: false
    property bool showPreviews: true

    SettingMeta on recolourIcons {
        label: "Recolour icons"
        description: "Tint dock icons with the secondary theme colour instead of showing them as-is."
        icon: "palette"
        inputType: SettingMeta.Switch
    }

    SettingMeta on showPreviews {
        label: "Window previews"
        description: "Show a live preview of each window in the dock hover popout. Turn off for a lighter, title-only popout."
        icon: "preview"
        inputType: SettingMeta.Switch
    }
}
