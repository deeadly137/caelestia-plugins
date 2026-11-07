import QtQuick
import Caelestia.Config

// One row in the launcher list. Dispatches between a stock desktop entry and a result contributed
// by a `launcher-provider` plugin without making AppItem know about plugins.
Item {
    id: root

    required property var modelData
    required property var screenState

    readonly property bool isPluginResult: modelData?.pluginLauncher === true

    function activate(): void {
        if (!root.isPluginResult)
            return;

        root.modelData.activate?.(root.screenState);
        if (!root.modelData.keepOpen)
            root.screenState.launcher = false;
    }

    implicitHeight: loader.item?.implicitHeight ?? Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    Loader {
        id: loader

        anchors.fill: parent
        sourceComponent: root.isPluginResult ? pluginItem : appItem
    }

    Component {
        id: appItem

        AppItem {
            modelData: root.modelData
            screenState: root.screenState
        }
    }

    Component {
        id: pluginItem

        PluginLauncherItem {
            modelData: root.modelData
            screenState: root.screenState

            onActivate: root.activate()
        }
    }
}
