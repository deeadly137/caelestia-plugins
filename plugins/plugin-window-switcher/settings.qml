import Caelestia.Plugins

SettingsObject {
    property string trigger: "windows "
    property bool activeWorkspaceOnly: true
    property int limit: 20

    SettingMeta on trigger {
        label: "Window trigger"
        description: "Prefix that shows the window list, including the trailing space."
        icon: "window"
        inputType: SettingMeta.TextField
    }

    SettingMeta on activeWorkspaceOnly {
        label: "Active workspace only"
        description: "List only windows on the focused workspace, including a focused special workspace."
        icon: "workspaces"
        inputType: SettingMeta.Switch
    }

    SettingMeta on limit {
        label: "Result limit"
        description: "Maximum number of windows shown per query."
        icon: "format_list_numbered"
        inputType: SettingMeta.SpinBox
        min: 1
        max: 100
    }
}
