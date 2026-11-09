import Caelestia.Plugins

// Same three options as midnight-shell's Picture in Picture page, stored in this plugin instead of
// shell.json. The utilities card is the quick way to pause and to pick the anchor quadrant; this
// page keeps the follow-focus option and labels the values.
SettingsObject {
    property string position: "top right"
    property bool followFocus: true
    property bool paused: false

    SettingMeta on position {
        label: "Position"
        description: "Anchor quadrant for Picture in Picture windows"
        icon: "picture_in_picture_alt"
        inputType: SettingMeta.Dropdown
        options: ["top left", "top center", "top right", "middle left", "middle center", "middle right", "bottom left", "bottom center", "bottom right"]
    }

    SettingMeta on followFocus {
        label: "Follow active focus"
        description: "Move Picture in Picture windows to the focused monitor"
        icon: "center_focus_strong"
        inputType: SettingMeta.Switch
    }

    SettingMeta on paused {
        label: "Pause auto-align"
        description: "Leave Picture in Picture windows where they are"
        icon: "pause"
        inputType: SettingMeta.Switch
    }
}
