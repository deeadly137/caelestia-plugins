import QtQuick
import QtMultimedia
import Caelestia.Plugins

// A desktop widget that covers the wallpaper but stays below normal windows. Video and animated
// image playback are entirely plugin-side; the shell only provides the surface.
Item {
    id: root

    required property SettingsObject settings

    readonly property string source: settings.source || Qt.resolvedUrl("loop.gif")
    readonly property bool isVideo: /\.(mp4|m4v|webm|mkv|mov|avi)$/i.test(source)

    Loader {
        anchors.fill: parent
        sourceComponent: root.isVideo ? videoComponent : imageComponent
    }

    Component {
        id: imageComponent

        AnimatedImage {
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            playing: true
        }
    }

    Component {
        id: videoComponent

        Video {
            id: video

            anchors.fill: parent
            source: root.source
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            autoPlay: true
            muted: true
        }
    }
}
