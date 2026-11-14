import Caelestia.Plugins

SettingsObject {
    property string trigger: "emoji "
    property string favouriteTrigger: "efav "
    property int limit: 20

    SettingMeta on trigger {
        label: "Emoji trigger"
        description: "Prefix that shows the emoji list, including the trailing space."
        icon: "emoji_emotions"
        inputType: SettingMeta.TextField
    }

    SettingMeta on favouriteTrigger {
        label: "Favourites trigger"
        description: "Prefix that lists emoji as favourite toggles and keeps the launcher open."
        icon: "star"
        inputType: SettingMeta.TextField
    }

    SettingMeta on limit {
        label: "Result limit"
        description: "Maximum number of emoji shown per query."
        icon: "format_list_numbered"
        inputType: SettingMeta.SpinBox
        min: 1
        max: 100
    }
}
