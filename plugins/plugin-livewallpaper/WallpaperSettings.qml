pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Plugins
import Caelestia.State
import qs.components
import qs.components.filedialog
import qs.services
import qs.modules.nexus.common

// Page extension for Nexus > Wallpaper & style. Videos are handled by the shell's normal background
// renderer; GIF/WebP use the desktop-widget overlay; Wallpaper Engine scenes run through
// linux-wallpaperengine and register an external provider so the shell background yields to it.
ColumnLayout {
    id: root

    required property SettingsObject settings

    readonly property string currentName: Wallpapers.actualCurrent ? Wallpapers.actualCurrent.split("/").pop() : ""
    readonly property string engineScene: String(root.settings.engineSource ?? "")
    readonly property bool engineActive: Wallpapers.externalProvider === "deeadly137/livewall"
    property string errorText: ""

    spacing: Tokens.spacing.extraSmall / 2

    function chooseEngineScene(path: string): void {
        let dir = String(path);
        if (dir.endsWith("/project.json"))
            dir = dir.slice(0, -"/project.json".length);

        if (!CUtils.fileExists(dir + "/project.json")) {
            root.errorText = Tr.tr("That folder does not contain project.json");
            return;
        }

        let preview = "";
        try {
            const project = JSON.parse(CUtils.readFile(dir + "/project.json"));
            if (project && typeof project.preview === "string" && project.preview.length > 0)
                preview = `${dir}/${project.preview}`;
        } catch (e) {
            console.warn("livewall: failed to parse project.json", e);
        }

        root.errorText = "";
        root.settings.engineSource = dir;

        // Use the scene preview as the wallpaper so the colour scheme and the wallpaper list stay
        // meaningful; the engine surface covers it while it is running.
        if (preview !== "" && CUtils.fileExists(preview))
            Wallpapers.setWallpaper(preview);
    }

    SectionHeader {
        text: Tr.tr("Live wallpaper")
    }

    RowButton {
        first: true
        icon: "video_file"
        text: Tr.tr("Video or animated image")
        subtext: root.settings.source || Tr.tr("None selected")
        trailingIcon: "folder_open"
        onClicked: picker.open()
    }

    ToggleRow {
        last: true
        text: Tr.tr("Play wallpaper")
        subtext: Tr.tr("Pause playback without changing the wallpaper")
        checked: PersistentState.wallpaperPlaying
        onToggled: PersistentState.wallpaperPlaying = checked
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        Layout.leftMargin: Tokens.padding.small
        text: root.currentName ? Tr.tr("Current wallpaper: %1").arg(root.currentName) : Tr.tr("Using the default wallpaper")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    SectionHeader {
        Layout.topMargin: Tokens.spacing.small
        text: Tr.tr("Wallpaper Engine")
    }

    RowButton {
        first: true
        icon: "movie_filter"
        text: Tr.tr("Scene")
        subtext: root.engineScene ? root.engineScene.split("/").pop() : Tr.tr("None selected")
        trailingIcon: "folder_open"
        onClicked: enginePicker.open()
    }

    ToggleRow {
        last: root.engineScene === ""
        text: Tr.tr("Mute engine audio")
        subtext: Tr.tr("Start linux-wallpaperengine with --silent")
        checked: root.settings.engineSilent ?? false
        onToggled: root.settings.engineSilent = checked
    }

    RowButton {
        last: true
        visible: root.engineScene !== ""
        icon: "close"
        text: Tr.tr("Clear scene")
        onClicked: {
            root.errorText = "";
            root.settings.engineSource = "";
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        Layout.leftMargin: Tokens.padding.small
        visible: root.errorText !== "" || root.engineScene !== ""
        text: root.errorText !== "" ? root.errorText : (root.engineActive ? Tr.tr("The engine is drawing the wallpaper on every monitor.") : Tr.tr("The scene starts once linux-wallpaperengine is available."))
        color: root.errorText !== "" ? Colours.palette.m3error : Colours.palette.m3outline
        font: Tokens.font.label.small
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    FileDialog {
        id: picker

        title: Tr.tr("Choose a live wallpaper")
        filterLabel: Tr.tr("Videos and animated images")
        filters: ["mp4", "m4v", "webm", "mkv", "mov", "avi", "gif", "webp"]
        onAccepted: path => {
            root.settings.source = path;
            Wallpapers.setWallpaper(path);
        }
    }

    FileDialog {
        id: enginePicker

        title: Tr.tr("Choose a Wallpaper Engine project")
        filterLabel: Tr.tr("Wallpaper Engine projects")
        filters: ["json"]
        onAccepted: path => root.chooseEngineScene(path)
    }
}
