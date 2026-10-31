pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Plugins
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// Synced lyrics for one screen. Geometry mirrors midnight-shell's background.desktopLyrics:
// a 350x180 box at one of nine positions, with margins that clear the bar on whichever edge it
// sits on. The entry point wrapper decides whether this copy is the desktop or the above-window
// one; this item only draws, it never takes pointer input.
Item {
    id: root

    required property SettingsObject settings

    // The above-window copy has no wallpaper behind it, so midnight-shell skips the blur there
    // and leaves only the plate tint. Same here: the wallpaper region is only sampled by the
    // desktop copy.
    property bool overlay: false

    readonly property var general: root.settings.general
    readonly property var appearance: root.settings.appearance
    readonly property var background: root.settings.background
    readonly property var shadow: root.settings.shadow

    readonly property var screen: Quickshell.screens.find(candidate => candidate.name === Config.screen) ?? null
    readonly property var player: Players.active

    readonly property bool enabled: root.general?.enabled ?? true
    property real lyricsScale: Math.max(0.5, Math.min(3, root.appearance?.scale ?? 1))
    readonly property bool bgEnabled: root.enabled && (root.background?.enabled ?? false)
    readonly property bool bgBlur: root.bgEnabled && (root.background?.blur ?? true) && !root.overlay && !Wallpapers.externalActive
    readonly property real bgOpacity: root.background?.opacity ?? 0.3
    readonly property bool shadowEnabled: root.shadow?.enabled ?? true
    readonly property real shadowOpacity: root.shadow?.opacity ?? 0.6
    readonly property real shadowBlur: root.shadow?.blur ?? 0.4

    readonly property bool invertColors: root.appearance?.invertColors ?? false
    readonly property bool useLightSet: Colours.light ? !root.invertColors : root.invertColors
    readonly property color safePrimary: root.useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: root.useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property string sansFont: GlobalConfig.appearance.font.body.family || "Sans Serif"

    // midnight-shell keeps a config-only alignment; its default (1) is centered.
    readonly property int alignment: 1
    readonly property int textAlignment: {
        switch (root.alignment) {
        case 0:
            return Text.AlignLeft;
        case 2:
            return Text.AlignRight;
        default:
            return Text.AlignHCenter;
        }
    }

    // Nine positions, same names as midnight-shell. An unknown stored value falls back to the
    // default instead of leaving the box unanchored.
    readonly property var positions: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]
    readonly property string position: root.positions.includes(String(root.appearance?.position ?? "")) ? String(root.appearance.position) : "bottom-center"

    // The bar can be on any edge, and the lyrics must sit clear of it. `exclusiveZone` is the
    // bar's reserved thickness (border thickness while it is hidden), so use the same fallback as
    // the desktop clock and the visualiser when the bar is not instantiated yet.
    readonly property string barPosition: Hooks.barPosition(Config)
    readonly property int barZone: ShellState.componentsFor(root.screen)?.bar?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
    readonly property real baseMargin: Tokens.padding.large * 2

    readonly property var monitor: root.screen ? Hypr.monitorFor(root.screen) : null
    readonly property bool hasFullscreen: root.monitor?.activeWorkspace?.toplevels?.values.some(toplevel => (toplevel.lastIpcObject?.fullscreen ?? 0) !== 0) ?? false
    readonly property bool hasTiled: root.monitor?.activeWorkspace?.toplevels?.values.some(toplevel => toplevel.lastIpcObject && !toplevel.lastIpcObject.floating && (toplevel.lastIpcObject.fullscreen ?? 0) === 0) ?? false
    readonly property bool shouldHide: ((root.general?.autoHideFullscreen ?? true) && root.hasFullscreen) || ((root.general?.autoHideTiled ?? true) && root.hasTiled)

    property int currentIndex: -1
    property string displayedLyric: ""
    property string previousLyricText: ""
    property string nextLyricText: ""

    readonly property bool hasText: root.displayedLyric.trim() !== "" || root.previousLyricText.trim() !== "" || root.nextLyricText.trim() !== ""
    readonly property bool showLoading: Lyrics.loading && !Lyrics.hasLyrics
    readonly property bool shown: root.enabled && !root.shouldHide && ((Lyrics.hasLyrics && root.hasText) || root.showLoading)

    // The shared Lyrics singleton is driven by whoever needs it; setTrack is idempotent, so this
    // coexists with the dashboard's lyric list.
    readonly property bool _trackSync: {
        const active = root.player;
        if (active && (active.trackTitle ?? "").length > 0)
            Lyrics.setTrack(active.trackArtist ?? "", active.trackTitle ?? "", active.trackAlbum ?? "", active.length ?? 0);
        else if (!active)
            Lyrics.clearTrack();
        return true;
    }

    function refreshLyrics(): void {
        if (!Lyrics.hasLyrics) {
            root.displayedLyric = "";
            root.previousLyricText = "";
            root.nextLyricText = "";
            return;
        }

        if (root.currentIndex >= 0) {
            root.displayedLyric = (Lyrics.lyrics[root.currentIndex] ?? "").replace(/\u00A0/g, " ");
            root.previousLyricText = root.currentIndex > 0 ? (Lyrics.lyrics[root.currentIndex - 1] ?? "").replace(/\u00A0/g, " ") : "";
            root.nextLyricText = root.currentIndex < Lyrics.lyrics.length - 1 ? (Lyrics.lyrics[root.currentIndex + 1] ?? "").replace(/\u00A0/g, " ") : "";
        } else {
            root.displayedLyric = "";
            root.previousLyricText = "";
            root.nextLyricText = (Lyrics.lyrics[0] ?? "").replace(/\u00A0/g, " ");
        }
    }

    function forceUpdate(): void {
        const nextIndex = Lyrics.hasLyrics ? Lyrics.indexForTime(root.player?.position ?? 0) : -1;
        if (nextIndex === root.currentIndex) {
            // Lyrics can arrive while the index stays -1 (the first line starts after 0:00), so the
            // text still has to refresh when the index did not change. Do not replay the slide
            // here: the timer calls this every tick and would re-run the transition on every tick.
            root.refreshLyrics();
            return;
        }

        root.currentIndex = nextIndex;
    }

    onCurrentIndexChanged: {
        root.refreshLyrics();
        lyricSlide.restart();
    }

    // The widget can appear after the track already loaded, or after enabling the plugin
    // mid-song (including while paused, when the timer does not run).
    Component.onCompleted: root.forceUpdate()

    Behavior on lyricsScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Timer {
        running: root.player?.isPlaying ?? false
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.forceUpdate()
    }

    Connections {
        target: Lyrics

        function onLyricsChanged(): void {
            root.forceUpdate();
        }

        function onHasLyricsChanged(): void {
            root.forceUpdate();
        }
    }

    Item {
        id: plate

        implicitWidth: 350 * root.lyricsScale
        implicitHeight: 180 * root.lyricsScale

        anchors.margins: root.baseMargin
        anchors.leftMargin: root.barPosition === "left" ? root.baseMargin + root.barZone : root.baseMargin
        anchors.rightMargin: root.barPosition === "right" ? root.baseMargin + root.barZone : root.baseMargin
        anchors.topMargin: root.barPosition === "top" ? root.baseMargin + root.barZone : root.baseMargin
        anchors.bottomMargin: root.barPosition === "bottom" ? root.baseMargin + root.barZone : root.baseMargin

        // Margin anchoring only offsets the anchors that are set, so a centered lyric would ignore
        // the extra margin on the bar edge; shift it back by half the bar instead.
        anchors.horizontalCenterOffset: {
            if (root.barPosition === "left")
                return root.barZone / 2;
            if (root.barPosition === "right")
                return -root.barZone / 2;
            return 0;
        }
        anchors.verticalCenterOffset: {
            if (root.barPosition === "top")
                return root.barZone / 2;
            if (root.barPosition === "bottom")
                return -root.barZone / 2;
            return 0;
        }

        state: root.position
        states: [
            State {
                name: "top-left"

                AnchorChanges {
                    target: plate
                    anchors.top: parent.top
                    anchors.left: parent.left
                }
            },
            State {
                name: "top-center"

                AnchorChanges {
                    target: plate
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            },
            State {
                name: "top-right"

                AnchorChanges {
                    target: plate
                    anchors.top: parent.top
                    anchors.right: parent.right
                }
            },
            State {
                name: "middle-left"

                AnchorChanges {
                    target: plate
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                }
            },
            State {
                name: "middle-center"

                AnchorChanges {
                    target: plate
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            },
            State {
                name: "middle-right"

                AnchorChanges {
                    target: plate
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                }
            },
            State {
                name: "bottom-left"

                AnchorChanges {
                    target: plate
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                }
            },
            State {
                name: "bottom-center"

                AnchorChanges {
                    target: plate
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            },
            State {
                name: "bottom-right"

                AnchorChanges {
                    target: plate
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                }
            }
        ]

        transitions: Transition {
            AnchorAnim {}
        }

        opacity: root.shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {}
        }

        Behavior on implicitWidth {
            Anim {
                type: Anim.StandardSmall
            }
        }

        Item {
            id: lyricsContainer

            anchors.fill: parent

            layer.enabled: root.shadowEnabled
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3shadow
                shadowOpacity: root.shadowOpacity
                shadowBlur: root.shadowBlur
            }

            // midnight-shell blurs a ShaderEffectSource of the wallpaper item, which it owns in the
            // same window. A plugin widget is its own layer surface, so the shell's wallpaper item
            // cannot be sampled from here; draw the wallpaper at screen size inside a plate-sized
            // clipped box instead, which captures the wallpaper pixels that sit behind the plate.
            Item {
                id: wallpaperRegion

                anchors.fill: parent
                clip: true
                visible: root.bgBlur

                Image {
                    id: wallpaperImage

                    x: -plate.x
                    y: -plate.y
                    width: root.width
                    height: root.height
                    source: Wallpapers.current
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Loader {
                id: blurLoader

                anchors.fill: parent
                active: root.bgBlur && wallpaperImage.status === Image.Ready
                visible: active

                sourceComponent: MultiEffect {
                    source: ShaderEffectSource {
                        sourceItem: wallpaperRegion
                        hideSource: true
                    }
                    maskSource: backgroundPlate
                    maskEnabled: true
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    autoPaddingEnabled: false
                }
            }

            StyledRect {
                id: backgroundPlate

                visible: root.bgEnabled
                anchors.fill: parent
                radius: Tokens.rounding.large * root.lyricsScale
                opacity: root.bgOpacity
                color: Colours.palette.m3surface

                layer.enabled: root.bgBlur
            }

            Loader {
                id: loadingIndicator

                anchors.centerIn: parent
                asynchronous: true
                active: opacity > 0
                opacity: Lyrics.loading && !Lyrics.hasLyrics ? 1 : 0

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.large * root.lyricsScale

                    StyledRect {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                        implicitHeight: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                        color: Colours.palette.m3primaryContainer
                        radius: Tokens.rounding.full

                        LoadingIndicator {
                            id: shape

                            anchors.centerIn: parent
                            implicitSize: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 5 * root.lyricsScale)
                            containsIcon: true
                            color: Colours.palette.m3primary
                        }
                    }

                    StyledText {
                        text: qsTr("Loading lyrics...")
                        color: root.safeSecondary
                        font.pointSize: Tokens.font.title.medium.pointSize * root.lyricsScale
                        font.family: Tokens.font.title.medium.family
                        font.weight: Tokens.font.title.medium.weight
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Item {
                id: fadeContainer

                anchors.fill: parent
                clip: true
                opacity: root.hasText ? 1 : 0

                layer.enabled: true
                layer.effect: Mask {
                    maskSource: fadeMask
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                Rectangle {
                    id: fadeMask

                    layer.enabled: true
                    visible: false
                    implicitWidth: fadeContainer.width
                    implicitHeight: fadeContainer.height

                    gradient: Gradient {
                        orientation: Gradient.Vertical

                        GradientStop {
                            color: Qt.alpha("black", 0)
                            position: 0
                        }
                        GradientStop {
                            color: Qt.alpha("black", 1)
                            position: 0.25
                        }
                        GradientStop {
                            color: Qt.alpha("black", 1)
                            position: 0.75
                        }
                        GradientStop {
                            color: Qt.alpha("black", 0)
                            position: 1
                        }
                    }
                }

                Item {
                    id: previousLine

                    width: parent.width
                    height: previousLabel.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.previousTargetY
                    visible: root.currentIndex > 0

                    StyledText {
                        id: previousLabel

                        anchors.fill: parent
                        text: root.previousLyricText
                        font.family: root.sansFont
                        font.pointSize: Tokens.font.body.medium.pointSize * root.lyricsScale
                        color: root.safeSecondary
                        opacity: 0.6
                        wrapMode: Text.WordWrap
                        horizontalAlignment: root.textAlignment
                    }
                }

                Item {
                    id: currentLine

                    width: parent.width
                    height: currentLabel.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.centerTargetY
                    visible: root.currentIndex >= 0

                    MultiEffect {
                        anchors.fill: currentLabel
                        source: currentLabel
                        scale: currentLabel.scale
                        enabled: root.currentIndex >= 0

                        blurEnabled: true
                        blur: 0.4

                        shadowEnabled: true
                        shadowColor: Colours.palette.m3primary
                        shadowOpacity: 0.5
                        shadowBlur: 0.6
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0

                        autoPaddingEnabled: true
                    }

                    StyledText {
                        id: currentLabel

                        width: parent.width
                        text: root.displayedLyric
                        font.family: root.sansFont
                        font.pointSize: Tokens.font.title.medium.pointSize * 1.3 * root.lyricsScale
                        font.weight: Font.Bold
                        color: Colours.palette.m3primary
                        wrapMode: Text.WordWrap
                        horizontalAlignment: root.textAlignment

                        Behavior on color {
                            CAnim {
                                duration: Tokens.anim.durations.expressiveFastEffects
                            }
                        }
                    }
                }

                Item {
                    id: nextLine

                    width: parent.width
                    height: nextLabel.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.nextTargetY
                    visible: root.nextLyricText.trim() !== ""

                    StyledText {
                        id: nextLabel

                        anchors.fill: parent
                        text: root.nextLyricText
                        font.family: root.sansFont
                        font.pointSize: Tokens.font.body.medium.pointSize * root.lyricsScale
                        color: root.safeSecondary
                        opacity: 0.6
                        wrapMode: Text.WordWrap
                        horizontalAlignment: root.textAlignment
                    }
                }
            }
        }
    }

    readonly property real lyricSpacing: Tokens.spacing.large * root.lyricsScale
    readonly property real centerTargetY: root.currentIndex >= 0 ? (fadeContainer.height - currentLine.height) / 2 : (fadeContainer.height - nextLine.height) / 2
    readonly property real previousTargetY: root.centerTargetY - previousLine.height - root.lyricSpacing
    readonly property real nextTargetY: root.currentIndex >= 0 ? root.centerTargetY + currentLine.height + root.lyricSpacing : root.centerTargetY
    readonly property real nextStartY: root.nextTargetY + nextLine.height + root.lyricSpacing

    SequentialAnimation {
        id: lyricSlide

        PropertyAction {
            target: previousLine
            property: "y"
            value: root.centerTargetY
        }
        PropertyAction {
            target: currentLine
            property: "y"
            value: root.nextTargetY
        }
        PropertyAction {
            target: nextLine
            property: "y"
            value: root.nextStartY
        }
        ParallelAnimation {
            NumberAnimation {
                target: previousLine
                property: "y"
                to: root.previousTargetY
                duration: Tokens.anim.durations.expressiveDefaultEffects
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: currentLine
                property: "y"
                to: root.centerTargetY
                duration: Tokens.anim.durations.expressiveDefaultEffects
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: nextLine
                property: "y"
                to: root.nextTargetY
                duration: Tokens.anim.durations.expressiveDefaultEffects
                easing.type: Easing.OutCubic
            }
        }
    }
}
