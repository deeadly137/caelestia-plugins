import Caelestia.Plugins

SettingsObject {
    property string source

    SettingMeta on source {
        label: "Video or animated image"
        description: "Absolute path to a video or animated image. Leave empty for the bundled demo."
        inputType: SettingMeta.TextField
    }
}
