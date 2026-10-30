import Caelestia.Plugins

SettingsObject {
    property string apiKey: ""

    property SettingsObject filters: SettingsObject {
        property bool general: true
        property bool anime: true
        property bool people: true

        property bool sfw: true
        property bool sketchy: false
        property bool nsfw: false

        property string sorting: "relevance"
        property string minimumResolution: "any"

        SettingMeta on general {
            label: "General"
            description: "General wallpapers."
            inputType: SettingMeta.Switch
        }

        SettingMeta on anime {
            label: "Anime"
            description: "Anime wallpapers."
            inputType: SettingMeta.Switch
        }

        SettingMeta on people {
            label: "People"
            description: "People wallpapers."
            inputType: SettingMeta.Switch
        }

        SettingMeta on sfw {
            label: "SFW"
            description: "Safe for work results."
            inputType: SettingMeta.Switch
        }

        SettingMeta on sketchy {
            label: "Sketchy"
            description: "Sketchy results. Requires an API key."
            inputType: SettingMeta.Switch
        }

        SettingMeta on nsfw {
            label: "NSFW"
            description: "Not safe for work results. Requires an API key."
            inputType: SettingMeta.Switch
        }

        SettingMeta on sorting {
            label: "Sorting"
            description: "How search results are ordered."
            icon: "sort"
            inputType: SettingMeta.SplitButton
            options: ["relevance", "date_added", "views", "favorites", "toplist", "random"]
        }

        SettingMeta on minimumResolution {
            label: "Minimum resolution"
            description: "Smallest result that will be returned."
            icon: "aspect_ratio"
            inputType: SettingMeta.SplitButton
            options: ["any", "1920x1080", "2560x1440", "3440x1440", "3840x2160"]
        }
    }

    SettingMeta on apiKey {
        label: "API key"
        description: "Optional. Required for sketchy and NSFW results. Create one in your Wallhaven account settings."
        icon: "key"
        inputType: SettingMeta.TextField
    }

    SettingMeta on filters {
        label: "Search filters"
        description: "Applied to every Wallhaven search."
        icon: "tune"
    }
}
