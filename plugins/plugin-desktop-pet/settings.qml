import Caelestia.Plugins

SettingsObject {
    property string path: "assets/pusheen"
    property int count: 1
    property real scale: 1
    property bool autoHide: false

    SettingMeta on path {
        label: "Frame pack"
        description: "Directory or .zip containing the standard 46-frame Shimeji pack. Relative paths resolve against the plugin directory."
        inputType: SettingMeta.TextField
    }

    SettingMeta on count {
        label: "Pets"
        description: "How many pets to show on each screen."
        inputType: SettingMeta.SpinBox
        min: 1
        max: 8
        step: 1
    }

    SettingMeta on scale {
        label: "Scale"
        description: "Size multiplier for the 128px frame pack."
        inputType: SettingMeta.Slider
        min: 0.5
        max: 2
        step: 0.05
    }

    SettingMeta on autoHide {
        label: "Hide when windows are open"
        description: "Only show the pet while the active workspace has no tiled windows."
        inputType: SettingMeta.Switch
    }
}

