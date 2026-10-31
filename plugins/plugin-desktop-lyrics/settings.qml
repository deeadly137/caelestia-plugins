import Caelestia.Plugins

// Same options and defaults as midnight-shell's `background.desktopLyrics`, and the same set the
// midnight Nexus page exposes. Midnight keeps an `alignment` value that its page never shows;
// this plugin has no way to declare a settings row the generated page hides, so the surface stays
// at the midnight default (centered) instead of showing a stray spin box.
SettingsObject {
    property bool overlay: false
    property bool autoHideFullscreen: true
    property bool autoHideTiled: true
    property real scale: 1
    property string position: "bottom-center"
    property bool invertColors: false

    property SettingsObject background: SettingsObject {
        property bool enabled: false
        property real opacity: 0.7
        property bool blur: true

        SettingMeta on enabled {
            label: "Enabled"
            description: "Draw a plate behind the lyrics."
            inputType: SettingMeta.Switch
        }

        SettingMeta on opacity {
            label: "Opacity"
            description: "Opacity of the plate colour."
            inputType: SettingMeta.Slider
            min: 0
            max: 1
            step: 0.05
        }

        SettingMeta on blur {
            label: "Blur"
            description: "Blur the wallpaper behind the plate."
            inputType: SettingMeta.Switch
        }
    }

    property SettingsObject shadow: SettingsObject {
        property bool enabled: true
        property real opacity: 0.7
        property real blur: 0.4

        SettingMeta on enabled {
            label: "Enabled"
            description: "Draw a shadow behind the lyrics."
            inputType: SettingMeta.Switch
        }

        SettingMeta on opacity {
            label: "Opacity"
            inputType: SettingMeta.Slider
            min: 0
            max: 1
            step: 0.05
        }

        SettingMeta on blur {
            label: "Blur"
            inputType: SettingMeta.Slider
            min: 0
            max: 2
            step: 0.1
        }
    }

    SettingMeta on background {
        label: "Background"
        description: "Plate drawn behind the lyrics."
    }

    SettingMeta on shadow {
        label: "Shadow"
        description: "Shadow drawn behind the lyrics."
    }

    SettingMeta on overlay {
        label: "Overlay"
        description: "Draw the lyrics on top of normal windows instead of on the desktop."
        inputType: SettingMeta.Switch
    }

    SettingMeta on autoHideFullscreen {
        label: "Hide on fullscreen"
        description: "Hide the lyrics while a fullscreen window is visible."
        inputType: SettingMeta.Switch
    }

    SettingMeta on autoHideTiled {
        label: "Hide on tiled windows"
        description: "Hide the lyrics while tiled windows are open."
        inputType: SettingMeta.Switch
    }

    SettingMeta on scale {
        label: "Scale"
        inputType: SettingMeta.Slider
        min: 0.5
        max: 3
        step: 0.05
    }

    SettingMeta on position {
        label: "Position"
        description: "Where the lyrics sit on the screen. Margins follow the taskbar edge."
        inputType: SettingMeta.BlobButton
        options: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]
        optionIcons: ["north_west", "north", "north_east", "west", "center_focus_weak", "east", "south_west", "south", "south_east"]
    }

    SettingMeta on invertColors {
        label: "Invert colours"
        description: "Invert the lyric colours, for light wallpapers."
        inputType: SettingMeta.Switch
    }
}
