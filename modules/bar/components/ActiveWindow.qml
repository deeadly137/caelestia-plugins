pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return Tr.trCtx("Desktop", "shown when no window is focused");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property bool isHorizontal: bar.isHorizontal

    readonly property int maxSize: {
        const otherModules = bar.children.filter(c => c.entryId && c.item !== this && c.entryId !== "spacer");
        const otherSize = otherModules.reduce((acc, curr) => acc + (isHorizontal ? (curr.item.implicitWidth ?? curr.width) : (curr.item.nonAnimHeight ?? curr.height)), 0);
        // Length - 2 cause repeater counts as a child
        return (isHorizontal ? bar.width : bar.height) - otherSize - bar.spacing * (bar.children.length - 1) - bar.vPadding * 2;
    }
    property Title current: text1

    clip: true
    implicitWidth: isHorizontal ? (icon.implicitWidth + current.width + current.anchors.leftMargin) : Math.max(icon.implicitWidth, current.width)
    implicitHeight: isHorizontal ? Math.max(icon.implicitHeight, current.height) : (icon.implicitHeight + current.height + current.anchors.topMargin)

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else if (Hypr.activeToplevel) {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.isHorizontal ? root.mapToItem(root.bar, root.implicitWidth / 2, 0).x : root.mapToItem(root.bar, 0, root.implicitHeight / 2).y;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined

        animate: true
        text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
        color: root.colour
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font: root.Tokens.font.body.builders.small.letterSpacing(1.4).build()
        elide: Qt.ElideRight
        elideWidth: root.maxSize - icon.width

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitHeight {
        enabled: !root.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        enabled: root.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    component Title: Item {
        id: textContainer

        property alias text: styledText.text

        width: root.isHorizontal ? styledText.implicitWidth : styledText.implicitHeight
        height: root.isHorizontal ? styledText.implicitHeight : styledText.implicitWidth

        anchors.horizontalCenter: root.isHorizontal ? undefined : icon.horizontalCenter
        anchors.verticalCenter: root.isHorizontal ? icon.verticalCenter : undefined
        anchors.top: root.isHorizontal ? undefined : icon.bottom
        anchors.topMargin: root.isHorizontal ? 0 : Tokens.spacing.small
        anchors.left: root.isHorizontal ? icon.right : undefined
        anchors.leftMargin: root.isHorizontal ? Tokens.spacing.small : 0

        opacity: root.current === this ? 1 : 0

        StyledText {
            id: styledText

            anchors.centerIn: parent

            font.pointSize: metrics.font.pointSize
            font.family: metrics.font.family
            font.letterSpacing: metrics.font.letterSpacing
            color: root.colour

            rotation: root.isHorizontal ? 0 : (root.Config.bar.activeWindow.inverted ? 270 : 90)
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
