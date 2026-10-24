import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property ScreenState screenState

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: {
            Apps.launch(root.modelData);
            root.screenState.launcher = false;
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        IconImage {
            id: icon

            asynchronous: true
            source: Quickshell.iconPath(root.modelData?.icon, "image-missing")
            implicitSize: parent.height * 0.8

            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.verticalCenter: icon.verticalCenter

            implicitWidth: parent.width - icon.width - hideIcon.width - favouriteIcon.width - Tokens.padding.small
            implicitHeight: name.implicitHeight + comment.implicitHeight

            StyledText {
                id: name

                text: root.modelData?.name ?? ""
                font: Tokens.font.body.medium
            }

            StyledText {
                id: comment

                text: (root.modelData?.comment || root.modelData?.genericName || root.modelData?.name) ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3outline

                elide: Text.ElideRight
                width: root.width - icon.width - hideIcon.width - favouriteIcon.width - Tokens.rounding.extraLargeIncreased

                anchors.top: name.bottom
            }
        }

        MouseArea {
            id: hideIcon

            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            hoverEnabled: true
            onClicked: {
                const appId = root.modelData?.id;
                if (!appId)
                    return;
                const hiddenApps = GlobalConfig.launcher.hiddenApps ? [...GlobalConfig.launcher.hiddenApps] : [];
                if (Strings.testRegexList(hiddenApps, appId)) {
                    const idx = hiddenApps.indexOf(appId);
                    if (idx !== -1)
                        hiddenApps.splice(idx, 1);
                } else {
                    hiddenApps.push(appId);
                }
                GlobalConfig.launcher.hiddenApps = hiddenApps;
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: Strings.testRegexList(GlobalConfig.launcher.hiddenApps, root.modelData?.id) ? "visibility_off" : "visibility"
                color: hideIcon.containsMouse ? Colours.palette.m3primary : Colours.palette.m3outline
            }
        }

        Loader {
            id: favouriteIcon

            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: hideIcon.left
            anchors.rightMargin: Tokens.padding.small
            active: root.modelData && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, root.modelData.id)

            sourceComponent: MaterialIcon {
                text: "favorite"
                fill: 1
                color: Colours.palette.m3primary
            }
        }
    }
}
