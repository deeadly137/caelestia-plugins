import Caelestia.Plugins

SettingsObject {
    property string trigger: "clip "
    property string favouriteTrigger: "cfav "
    property int historySize: 20
    property bool showImages: true

    SettingMeta on trigger {
        label: "Clipboard trigger"
        description: "Prefix that shows the clipboard history, including the trailing space."
        icon: "content_paste"
        inputType: SettingMeta.TextField
    }

    SettingMeta on favouriteTrigger {
        label: "Favourites trigger"
        description: "Prefix that lists clips as favourite toggles and keeps the launcher open."
        icon: "star"
        inputType: SettingMeta.TextField
    }

    SettingMeta on historySize {
        label: "History size"
        description: "Maximum number of clips shown per query."
        icon: "history"
        inputType: SettingMeta.SpinBox
        min: 1
        max: 100
    }

    SettingMeta on showImages {
        label: "Show images"
        description: "Include binary clipboard entries. They are copied as images, not previewed."
        icon: "image"
        inputType: SettingMeta.Switch
    }
}
