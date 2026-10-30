import Caelestia.Plugins

SettingsObject {
    property string shell: "fish"
    property string barPosition: "left"
    property var hiddenApps: []

    // Bar status icons
    property bool showNotifications: true
    property bool showPeripheralBattery: false
    property var peripheralBatteryExcluded: []

    // Pause video and animated wallpapers while a fullscreen window is visible
    property bool pauseVideoOnFullscreen: true

    // Sidebar tabs
    property bool showNews: true
    property string initialSidebarTab: "notifications"

    // AI assistant providers. These live here instead of the shell config so the whole feature
    // disappears when the plugin is disabled.
    property bool aiEnableOllama: true
    property string aiOllamaUrl: "http://localhost:11434"
    property string aiDefaultOllamaModel: "llama3"

    property bool aiEnableOpenRouter: false
    property string aiOpenRouterUrl: "https://openrouter.ai/api/v1"
    property string aiOpenRouterApiKey: ""
    property string aiOpenRouterModel: "openrouter/auto"

    property bool aiEnableOpenClaw: false
    property string aiOpenClawUrl: "http://127.0.0.1:18789"
    property string aiOpenClawToken: ""
    property string aiOpenClawModel: "openclaw/default"

    property bool aiEnableCelestialMode: false
    property string aiActiveProvider: "ollama"
    property var aiRecentModels: []
    property string aiOllamaHistoryJson: "[]"

    SettingMeta on shell {
        label: "Terminal shell"
        description: "Executable used by the dashboard terminal tab. Must accept -c COMMAND."
        inputType: SettingMeta.TextField
    }

    SettingMeta on barPosition {
        label: "Bar position"
        description: "Screen edge the taskbar sits on. Empty follows the shell's own setting."
        inputType: SettingMeta.SplitButton
        options: ["left", "right", "top", "bottom"]
        optionIcons: ["west", "east", "north", "south"]
    }

    SettingMeta on showNotifications {
        label: "Notifications icon"
        description: "Show the notification status icon in the bar."
        inputType: SettingMeta.Switch
    }

    SettingMeta on showPeripheralBattery {
        label: "Peripheral battery icons"
        description: "Show batteries of mice, keyboards and headsets in the bar."
        inputType: SettingMeta.Switch
    }

    SettingMeta on pauseVideoOnFullscreen {
        label: "Pause on fullscreen"
        description: "Pause video and animated wallpapers while a fullscreen window is visible."
        inputType: SettingMeta.Switch
    }

    SettingMeta on showNews {
        label: "News tab"
        description: "Show the Arch Linux news feed next to the notifications."
        inputType: SettingMeta.Switch
    }

    SettingMeta on initialSidebarTab {
        label: "Sidebar opens on"
        description: "Tab selected when the sidebar is opened."
        inputType: SettingMeta.SplitButton
        options: ["notifications", "ai", "news"]
        optionIcons: ["notifications", "smart_toy", "newspaper"]
    }

    SettingMeta on aiEnableOllama {
        label: "Ollama"
        description: "Use a local or remote Ollama server."
        inputType: SettingMeta.Switch
    }

    SettingMeta on aiOllamaUrl {
        label: "Ollama server"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiDefaultOllamaModel {
        label: "Ollama model"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiEnableOpenRouter {
        label: "OpenRouter"
        description: "Use OpenRouter's cloud API."
        inputType: SettingMeta.Switch
    }

    SettingMeta on aiOpenRouterUrl {
        label: "OpenRouter URL"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiOpenRouterApiKey {
        label: "OpenRouter API key"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiOpenRouterModel {
        label: "OpenRouter model"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiEnableOpenClaw {
        label: "OpenClaw"
        description: "Use a self-hosted OpenClaw gateway."
        inputType: SettingMeta.Switch
    }

    SettingMeta on aiOpenClawUrl {
        label: "OpenClaw URL"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiOpenClawToken {
        label: "OpenClaw token"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiOpenClawModel {
        label: "OpenClaw model"
        inputType: SettingMeta.TextField
    }

    SettingMeta on aiEnableCelestialMode {
        label: "Celestial mode"
        description: "Let the assistant search the web. Requires python-playwright."
        inputType: SettingMeta.Switch
    }
}
