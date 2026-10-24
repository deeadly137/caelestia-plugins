pragma ComponentBehavior: Bound

import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.services
import qs.modules.bar.popouts as BarPopouts

GridLayout {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large
    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property int spacing: Tokens.spacing.medium

    columns: isHorizontal ? -1 : 1
    rows: isHorizontal ? 1 : -1
    columnSpacing: spacing
    rowSpacing: spacing
    flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper)?.item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(position: real): void {
        const ch = isHorizontal ? childAt(position, height / 2) as EntryWrapper : childAt(width / 2, position) as EntryWrapper;

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const start = isHorizontal ? ch.x : ch.y;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = isHorizontal ? items.childAt(mapToItem(items, position, 0).x, items.height / 2) : items.childAt(items.width / 2, mapToItem(items, 0, position).y);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => isHorizontal ? icon.mapToItem(root, icon.implicitWidth / 2, 0).x : icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            const overExpand = isHorizontal ? tray.expandIcon.contains(mapToItem(tray.expandIcon, position, tray.implicitHeight / 2)) : tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, position));
            if (!Config.bar.tray.compact || (tray.expanded && !overExpand)) {
                const offset = position - start - tray.padding * 2 + tray.spacing;
                const index = isHorizontal ? Math.floor((offset / tray.layout.implicitWidth) * tray.items.count) : Math.floor((offset / tray.layout.implicitHeight) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => isHorizontal ? trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x : trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = isHorizontal ? (ch.item as Item).mapToItem(root, (ch.item as Item).implicitWidth / 2, 0).x ?? 0 : (ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y ?? 0;
            popouts.hasCurrent = true;
        } else {
            const pluginPopout = Plugins.entryPoints(EntryPointType.BarPopout).find(p => p.properties.entry === id);
            if (pluginPopout) {
                popouts.currentName = id.toLowerCase();
                popouts.currentCenter = isHorizontal ? (ch.item as Item).mapToItem(root, (ch.item as Item).implicitWidth / 2, 0).x ?? 0 : (ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y ?? 0;
                popouts.hasCurrent = true;
            }
        }
    }

    function handleWheel(position: real, angleDelta: point): void {
        const ch = isHorizontal ? childAt(position, height / 2) as EntryWrapper : childAt(width / 2, position) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = Hypr.monitorFor(screen);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || mon.activeWorkspace?.id > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if ((isHorizontal ? position < width / 2 : position < height / 2) && Config.bar.scrollActions.volume) {
            // Volume scroll on the first half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on the second half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    Repeater {
        id: repeater

        model: ScriptModel {
            // Configured entries keep their order. Plugin bar entries are appended after them,
            // sorted by `properties.order` then name, but only when the config does not mention
            // their id at all — `{ "id": "<name>", "enabled": false }` hides an auto-added entry.
            values: {
                CUtils.dependency(Plugins.entryPointsRevision);

                const configured = root.Config.bar.entries.values;
                const placed = new Set(configured.map(entry => entry.id));

                const extra = Plugins.entryPoints(EntryPointType.BarEntry)
                    .filter(entry => !placed.has(entry.properties.name ?? ""))
                    .sort((a, b) => {
                        const byOrder = (a.properties.order ?? 100) - (b.properties.order ?? 100);
                        return byOrder !== 0 ? byOrder : (a.properties.name ?? "").localeCompare(b.properties.name ?? "");
                    })
                    .map(entry => ({
                        id: entry.properties.name,
                        enabled: true
                    }));

                return configured.filter(entry => entry.enabled).concat(extra);
            }
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillWidth: root.isHorizontal
                    Layout.fillHeight: !root.isHorizontal
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    Workspaces {
                        objectName: "taskbarWorkspaces"
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    ActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    Tray {
                        objectName: "taskbarTray"
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    Clock {
                        objectName: "taskbarClock"
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    StatusIcons {
                        objectName: "taskbarStatusIcons"
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
            DelegateChoice {
                delegate: EntryWrapper {
                    id: pluginEntryWrapper

                    EntryPointLoader {
                        entryPoint: {
                            const id = pluginEntryWrapper.modelData.id;
                            const entry = Plugins.entryPoints(EntryPointType.BarEntry).find(e => e.properties.name === id);
                            if (!entry)
                                console.warn(logCat, "No plugin entry point found for", id);
                            return entry;
                        }
                    }
                }
            }
        }
    }

    LoggingCategory {
        id: logCat

        name: "caelestia.bar"
        defaultLogLevel: LoggingCategory.Info
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.leftMargin: root.isHorizontal && index === 0 ? root.vPadding : 0
        Layout.rightMargin: root.isHorizontal && index === repeater.count - 1 ? root.vPadding : 0
        Layout.topMargin: !root.isHorizontal && index === 0 ? root.vPadding : 0
        Layout.bottomMargin: !root.isHorizontal && index === repeater.count - 1 ? root.vPadding : 0
        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
