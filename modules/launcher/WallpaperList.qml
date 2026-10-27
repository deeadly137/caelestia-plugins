pragma ComponentBehavior: Bound

import "items"
import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.utils

PathView {
    id: root

    required property SearchBar search
    required property var screenState
    required property var panels
    required property var content
    required property var contentList

    readonly property int itemWidth: Tokens.sizes.launcher.wallpaperWidth * 0.8 + Tokens.padding.medium * 2

    readonly property int numItems: {
        const screen = (QsWindow.window as QsWindow)?.screen;
        if (!screen)
            return 0;

        // Screen width - 4x outer rounding - 2x max side thickness (cause centered)
        const barMargins = Math.max(Config.border.thickness, panels.bar.isHorizontal ? panels.bar.implicitHeight : panels.bar.implicitWidth);
        let outerMargins = 0;
        if (panels.popouts.hasCurrent && panels.popouts.currentCenter + panels.popouts.nonAnimHeight / 2 > screen.height - content.implicitHeight - Config.border.thickness * 2)
            outerMargins = panels.popouts.nonAnimWidth;
        if ((screenState.utilities || screenState.sidebar) && panels.utilities.implicitWidth > outerMargins)
            outerMargins = panels.utilities.implicitWidth;
        const maxWidth = screen.width - Config.border.rounding * 4 - (barMargins + outerMargins) * 2;

        if (maxWidth <= 0)
            return 0;

        const maxItemsOnScreen = Math.floor(maxWidth / itemWidth);
        const visible = Math.min(maxItemsOnScreen, Config.launcher.maxWallpapers, scriptModel.values.length);

        if (visible === 2)
            return 1;
        if (visible > 1 && visible % 2 === 0)
            return visible - 1;
        return visible;
    }

    model: ScriptModel {
        id: scriptModel

        readonly property string search: root.search.text.split(" ").slice(1).join(" ")

        values: {
            const categories = Wallpapers.categories;
            const targetCategory = root.contentList.activeWallpaperTab;
            const baseDir = Paths.wallsdir;
            const allWalls = search || categories.length === 0 ? Wallpapers.query(search) : (Wallpapers.grouped[targetCategory] || []);

            if (!search || categories.length === 0)
                return allWalls;

            if (targetCategory === "Main")
                return allWalls.filter(w => w.parentDir === baseDir);
            if (targetCategory === "Wallpaper Engine")
                return allWalls.filter(w => w.parentDir.includes("steamapps/workshop/content/431960"));
            return allWalls.filter(w => {
                let cat = w.parentDir.slice(baseDir.length + 1);
                if (cat.includes("/"))
                    cat = cat.slice(0, cat.indexOf("/"));
                return cat === targetCategory;
            });
        }

        onValuesChanged: {
            const idx = search ? 0 : values.findIndex(w => w.path === Wallpapers.actualCurrent);
            root.currentIndex = Math.max(0, idx);
            if (values.length > 0 && root.currentIndex >= 0 && root.currentIndex < values.length)
                previewTimer.restart();
        }
    }

    Timer {
        id: previewTimer

        interval: 100

        onTriggered: {
            if (root.currentItem)
                Wallpapers.preview((root.currentItem as WallpaperItem).modelData.path);
        }
    }

    Component.onCompleted: currentIndex = Wallpapers.list.findIndex(w => w.path === Wallpapers.actualCurrent)
    Component.onDestruction: Wallpapers.stopPreview()

    onCurrentItemChanged: previewTimer.restart()

    implicitWidth: Math.min(numItems, count) * itemWidth
    pathItemCount: numItems
    cacheItemCount: 4

    snapMode: PathView.SnapToItem
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange

    delegate: WallpaperItem {
        screenState: root.screenState
    }

    path: Path {
        startY: root.height / 2

        PathAttribute {
            name: "z"
            value: 0
        }
        PathLine {
            x: root.width / 2
            relativeY: 0
        }
        PathAttribute {
            name: "z"
            value: 1
        }
        PathLine {
            x: root.width
            relativeY: 0
        }
    }

    CustomMouseArea {
        function onWheel(event: WheelEvent): void {
            if (event.angleDelta.y > 0)
                root.decrementCurrentIndex();
            else if (event.angleDelta.y < 0)
                root.incrementCurrentIndex();
        }

        anchors.fill: parent
    }
}
