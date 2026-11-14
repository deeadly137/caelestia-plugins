import Caelestia.Plugins

SettingsObject {
    property string trigger: "keybinds "
    property int limit: 100

    SettingMeta on trigger {
        label: "Keybinds trigger"
        description: "Prefix that shows the keybind list, including the trailing space."
        icon: "keyboard"
        inputType: SettingMeta.TextField
    }

    SettingMeta on limit {
        label: "Result limit"
        description: "Maximum number of keybinds shown per query."
        icon: "format_list_numbered"
        inputType: SettingMeta.SpinBox
        min: 1
        max: 500
    }
}
