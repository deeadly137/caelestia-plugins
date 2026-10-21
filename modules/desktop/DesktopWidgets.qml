pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Plugins
import qs.components.containers
import qs.services

// Desktop widget hosts. Bottom widgets sit above the wallpaper but below normal windows. Top
// widgets (for example an animated desktop pet) sit above normal windows, so their input is
// restricted to the regions the plugin exposes through its `inputMask` property.
Item {
    id: root

    readonly property var widgets: Plugins.entryPoints(EntryPointType.DesktopWidget)
    readonly property var bottomWidgets: widgets.filter(widget => String(widget.properties?.layer ?? "bottom") !== "top")
    readonly property var topWidgets: widgets.filter(widget => String(widget.properties?.layer ?? "bottom") === "top")

    Variants {
        model: root.bottomWidgets.length > 0 ? Screens.screens : []

        StyledWindow {
            id: bottomWin

            required property ShellScreen modelData

            screen: modelData
            name: "desktop-widgets"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            surfaceFormat.opaque: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Repeater {
                model: root.bottomWidgets

                EntryPointLoader {
                    required property var modelData

                    anchors.fill: parent
                    entryPoint: modelData
                }
            }
        }
    }

    Variants {
        model: root.topWidgets.length > 0 ? Screens.screens : []

        StyledWindow {
            id: topWin

            required property ShellScreen modelData

            readonly property var inputMasks: {
                const revision = maskRevision; // Re-evaluate when a loader finishes or a plugin item changes
                const masks = [];
                for (let i = 0; i < widgetRepeater.count; i++) {
                    const loader = widgetRepeater.itemAt(i);
                    const mask = loader?.item?.inputMask;
                    if (mask)
                        masks.push(mask);
                }
                return revision >= 0 ? masks : [];
            }

            property int maskRevision: 0

            function refreshMasks(): void {
                maskRevision++;
            }

            screen: modelData
            name: "desktop-widgets-top"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            surfaceFormat.opaque: false

            // An empty region makes the whole surface click-through. Plugins that want input must
            // expose `inputMask` (a Quickshell Region) from their root item.
            mask: Region {
                regions: topWin.inputMasks
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Repeater {
                id: widgetRepeater

                model: root.topWidgets

                EntryPointLoader {
                    required property var modelData

                    anchors.fill: parent
                    entryPoint: modelData
                    onItemChanged: topWin.refreshMasks()
                }
            }
        }
    }
}
