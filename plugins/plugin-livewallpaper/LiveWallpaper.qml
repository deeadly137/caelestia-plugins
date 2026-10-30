import QtQuick
import Caelestia.Plugins
import qs.services

// Animated GIF/WebP wallpapers need an AnimatedImage; the shell's background Visual only keeps a
// still frame for those formats. Videos are rendered by the normal background path instead. The
// overlay yields to an external provider (Wallpaper Engine) and follows the shared pause state.
Item {
    id: root

    required property SettingsObject settings

    readonly property string source: settings.source || ""
    readonly property bool isAnimated: /\.(gif|webp|apng)$/i.test(source)
    readonly property bool active: isAnimated && source.length > 0 && Wallpapers.actualCurrent === source && !Wallpapers.externalActive

    visible: active

    AnimatedImage {
        anchors.fill: parent
        source: root.active ? root.source : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        playing: Wallpapers.playing
    }
}
