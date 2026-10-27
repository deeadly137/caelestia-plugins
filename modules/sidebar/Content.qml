pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Props props
    required property ScreenState screenState
    property var popouts
    property var utilities

    // A plugin may replace the whole sidebar body, e.g. to add tabs next to the notifications. The
    // first entry of the `sidebar.content` slot wins and the stock body is skipped.
    readonly property var pluginContent: Hooks.slot("sidebar.content")[0] ?? null
    // A replacement may ask the sidebar to stay loaded while it is hidden (a streaming answer).
    readonly property bool keepAlive: pluginLoader.item?.keepAlive === true

    Loader {
        id: pluginLoader

        anchors.fill: parent
        sourceComponent: root.pluginContent ? root.pluginContent.component : null

        onLoaded: {
            if (!item)
                return;
            for (const key in root.pluginContent.properties)
                item[key] = root.pluginContent.properties[key];
            item.props = root.props;
            item.screenState = root.screenState;
            item.popouts = root.popouts;
            item.utilities = root.utilities;
        }
    }

    Loader {
        anchors.fill: parent
        active: root.pluginContent === null
        sourceComponent: stockContent
    }

    Component {
        id: stockContent

        ColumnLayout {
            id: layout

            anchors.fill: parent
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true

                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                NotifDock {
                    objectName: "sidebarNotifications"

                    props: root.props
                    screenState: root.screenState
                }
            }

            StyledRect {
                Layout.topMargin: Tokens.padding.large - layout.spacing
                Layout.fillWidth: true
                implicitHeight: 1

                color: Colours.tPalette.m3outlineVariant
            }
        }
    }
}
