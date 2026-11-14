pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.modules.utilities.cards
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property var props
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property matrix4x4 deformMatrix

    // Bumped when a plugin card loads or is replaced, so the height/count bindings re-evaluate.
    property int pluginCardRevision: 0

    readonly property var pluginCards: {
        CUtils.dependency(Plugins.entryPointsRevision);
        return Array.from(Plugins.entryPoints(EntryPointType.UtilitiesCard))
            .slice()
            .sort((a, b) => {
                const byOrder = (a.properties.order ?? 100) - (b.properties.order ?? 100);
                return byOrder !== 0 ? byOrder : (a.properties.name ?? "").localeCompare(b.properties.name ?? "");
            });
    }

    readonly property int pluginCardCount: {
        void root.pluginCardRevision;

        let count = 0;
        for (let i = 0; i < pluginRepeater.count; i++)
            if (root.cardVisible(pluginRepeater.itemAt(i)))
                count++;
        return count;
    }

    readonly property real pluginCardHeight: {
        void root.pluginCardRevision;

        let height = 0;
        for (let i = 0; i < pluginRepeater.count; i++) {
            const loader = pluginRepeater.itemAt(i);
            if (root.cardVisible(loader))
                height += loader.item.implicitHeight ?? 0;
        }
        return height;
    }

    readonly property int enabledCards: (idleInhibit.active ? 1 : 0) + (record.active ? 1 : 0) + (toggles.active ? 1 : 0) + pluginCardCount
    readonly property real nonAnimHeight: ((idleInhibit.item as IdleInhibit)?.nonAnimHeight ?? 0) + ((record.item as Record)?.nonAnimHeight ?? 0) + ((toggles.item as Toggles)?.implicitHeight ?? 0) + pluginCardHeight + layout.spacing * Math.max(0, enabledCards - 1)

    // A card must be an Item; `visible` is how a plugin hides a card that has nothing to show, and
    // an invisible card must not take a slot in the column.
    function cardVisible(loader): bool {
        const item = loader?.item;
        return item instanceof Item && loader.visible && item.visible;
    }

    function injectCard(loader, item): void {
        if (!item)
            return;

        loader.injectProperties(item, {
            props: root.props,
            screenState: root.screenState,
            popouts: root.popouts
        });
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        Loader {
            id: idleInhibit

            Layout.fillWidth: true
            active: Config.utilities.cards.keepAwake
            visible: active

            sourceComponent: IdleInhibit {
                objectName: "utilitiesKeepAwake"
            }
        }

        Loader {
            id: record

            Layout.fillWidth: true
            active: Config.utilities.cards.recorder
            visible: active
            z: 1

            sourceComponent: Record {
                objectName: "utilitiesScreenRecorder"

                props: root.props
                screenState: root.screenState
            }
        }

        Loader {
            id: toggles

            Layout.fillWidth: true
            active: Config.utilities.cards.quickToggles
            visible: active

            sourceComponent: Toggles {
                objectName: "utilitiesQuickToggles"

                screenState: root.screenState
                popouts: root.popouts
            }
        }

        Repeater {
            id: pluginRepeater

            model: root.pluginCards

            delegate: EntryPointLoader {
                id: cardLoader

                required property var modelData

                Layout.fillWidth: true
                entryPoint: modelData

                onItemChanged: {
                    root.pluginCardRevision++;
                    if (!item)
                        return;

                    root.injectCard(cardLoader, item);
                }

                onLoaded: root.pluginCardRevision++
            }
        }
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
