import Caelestia.Plugins

SettingsObject {
    property string source
    property string engineSource
    property bool engineSilent: false
    property real engineVolume: 0.15

    SettingMeta on source {
        label: "Video or animated image"
        description: "Absolute path to a video, GIF, or animated WebP. Use the controls in Wallpaper & style to pick one."
        inputType: SettingMeta.TextField
    }

    SettingMeta on engineSource {
        label: "Wallpaper Engine scene"
        description: "Scene directory (the folder containing project.json). Use the controls in Wallpaper & style to pick one."
        inputType: SettingMeta.TextField
    }

    SettingMeta on engineSilent {
        label: "Mute engine audio"
        description: "Pass --silent to linux-wallpaperengine."
        inputType: SettingMeta.Switch
    }

    SettingMeta on engineVolume {
        label: "Engine volume"
        description: "Audio volume for scenes that support it (0 to 1)."
        inputType: SettingMeta.Slider
        min: 0
        max: 1
        step: 0.05
    }
}
