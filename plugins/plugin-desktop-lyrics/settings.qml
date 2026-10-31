import Caelestia.Plugins

// Same groups, rows and labels as midnight-shell's Desktop lyrics page. Midnight keeps an
// `alignment` value its page never shows; this plugin has no way to declare a settings row the
// generated page hides, so the surface stays at the midnight default (centered) instead.
SettingsObject {
    property SettingsObject general: SettingsObject {
        property bool enabled: true
        property bool overlay: false
        property bool autoHideFullscreen: true
        property bool autoHideTiled: true

        SettingMeta on enabled {
            label: "Enable desktop lyrics"
            inputType: SettingMeta.Switch
        }

        SettingMeta on overlay {
            label: "Overlay lyrics"
            description: "Render lyrics on top of windows"
            inputType: SettingMeta.Switch
        }

        SettingMeta on autoHideFullscreen {
            label: "Auto-hide for fullscreen windows"
            description: "Hide lyrics when a window is fullscreen"
            inputType: SettingMeta.Switch
        }

        SettingMeta on autoHideTiled {
            label: "Auto-hide for tiled windows"
            description: "Hide lyrics when tiled windows are open"
            inputType: SettingMeta.Switch
        }
    }

    property SettingsObject appearance: SettingsObject {
        property string position: "bottom-center"
        property real scale: 1
        property bool invertColors: false

        SettingMeta on position {
            label: "Position"
            inputType: SettingMeta.Dropdown
            options: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]
        }

        SettingMeta on scale {
            label: "Scale"
            inputType: SettingMeta.Slider
            min: 0.5
            max: 3
            step: 0.1
            suffix: "x"
        }

        SettingMeta on invertColors {
            label: "Invert colors"
            description: "Invert the lyrics color when using a light wallpaper"
            inputType: SettingMeta.Switch
        }
    }

    property SettingsObject background: SettingsObject {
        property bool enabled: false
        property real opacity: 0.3
        property bool blur: true

        SettingMeta on enabled {
            label: "Enable background"
            inputType: SettingMeta.Switch
        }

        SettingMeta on opacity {
            label: "Opacity"
            inputType: SettingMeta.Slider
            min: 0
            max: 1
            step: 0.05
            displayScale: 100
            suffix: "%"
        }

        SettingMeta on blur {
            label: "Blur"
            inputType: SettingMeta.Switch
        }
    }

    property SettingsObject shadow: SettingsObject {
        property bool enabled: true
        property real opacity: 0.6
        property real blur: 0.4

        SettingMeta on enabled {
            label: "Enable shadow"
            inputType: SettingMeta.Switch
        }

        SettingMeta on opacity {
            label: "Opacity"
            inputType: SettingMeta.Slider
            min: 0
            max: 1
            step: 0.05
            displayScale: 100
            suffix: "%"
        }

        SettingMeta on blur {
            label: "Blur strength"
            inputType: SettingMeta.Slider
            min: 0
            max: 2
            step: 0.1
        }
    }

    SettingMeta on general {
        label: "General"
    }

    SettingMeta on appearance {
        label: "Appearance"
    }

    SettingMeta on background {
        label: "Background"
    }

    SettingMeta on shadow {
        label: "Shadow"
    }
}
