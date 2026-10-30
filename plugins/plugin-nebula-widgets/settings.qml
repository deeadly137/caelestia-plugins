import Caelestia.Plugins

SettingsObject {
    property bool corner: true

    SettingMeta on corner {
        label: "Corner widget list"
        description: "Hover the bottom-left corner to add, open or remove widgets."
        icon: "widgets"
        inputType: SettingMeta.Switch
    }
}
