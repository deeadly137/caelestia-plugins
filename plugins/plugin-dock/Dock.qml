// Port of midnight-shell's dock. It is a `bar-entry` so it lives in the bar window and can use the
// bar's orientation, screen and popouts. Pinned apps come first, then running windows grouped by
// class; clicking focuses or launches, right-click opens the context popout and hovering an icon
// opens the window preview popout. The hover/context popouts are separate `bar-popout` entries in
// this plugin that read `popouts.dockModel`.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property SettingsObject settings

    // Injected by the bar entry host: the surrounding bar and its popout state.
    property var bar: null
    property var popouts: null

    readonly property var popoutState: root.popouts ?? root.bar?.popouts ?? null
    readonly property bool horizontal: root.bar?.isHorizontal ?? true
    readonly property bool recolourIcons: root.settings?.recolourIcons ?? false
    readonly property int iconSize: Math.round((Tokens.sizes.bar.innerWidth * 0.8) / 2) * 2
    readonly property int padding: Tokens.padding.medium
    readonly property int spacing: Tokens.spacing.small

    property int modelUpdateTrigger: 0
    property var launchingApps: ({})
    property var modelDataArray: []
    property var currentOrder: []
    property var toplevels: Hyprland.toplevels.values
    property var activeTop: Hyprland.activeToplevel

    function openPopout(name: string, model: var, center: real): void {
        const state = root.popoutState;
        if (!state)
            return;

        state.currentName = name;
        state.currentCenter = center;
        state.dockModel = model;
        state.hasCurrent = true;
    }

    // Pointer moves over the dock are routed here by `Bar.checkPopout()`. The bar only knows the
    // whole entry, so the dock maps the position back to the icon under the cursor.
    function handleHover(relPos: real, isHorizontal: bool): void {
        const state = root.popoutState;
        if (!state)
            return;

        // Don't close an open context menu or replace the active-window popout while the pointer
        // is still over the dock.
        if (state.hasCurrent && (state.currentName === "dockcontext" || state.currentName === "activewindow"))
            return;

        const itemSize = root.iconSize;
        const itemWidthWithSpacing = itemSize + root.spacing;
        const adjustedPos = isHorizontal ? relPos - container.x - root.padding : relPos - container.y - root.padding;

        // Only close if the cursor is completely outside the dock bounds.
        if (adjustedPos < 0 || adjustedPos >= root.modelDataArray.length * itemWidthWithSpacing) {
            state.hasCurrent = false;
            return;
        }

        const index = Math.floor(adjustedPos / itemWidthWithSpacing);
        if (index < 0 || index >= root.modelDataArray.length)
            return;

        const centerOffset = index * itemWidthWithSpacing + itemSize / 2;
        const absoluteCenter = isHorizontal ? container.mapToItem(null, root.padding + centerOffset, 0).x : container.mapToItem(null, 0, root.padding + centerOffset).y;
        root.openPopout("dockhover", root.modelDataArray[index], absoluteCenter);
    }

    function saveNewOrder(): void {
        const newArr = [];
        const newFavs = [];

        for (let i = 0; i < root.currentOrder.length; ++i) {
            const mData = root.currentOrder[i];
            if (!mData)
                continue;

            if (mData.isPinned)
                newFavs.push(mData.id);

            newArr.push(mData);
        }

        const currentFavs = GlobalConfig.launcher.favouriteApps || [];
        let changed = currentFavs.length !== newFavs.length;
        if (!changed) {
            for (let i = 0; i < newFavs.length; i++) {
                if (currentFavs[i] !== newFavs[i]) {
                    changed = true;
                    break;
                }
            }
        }

        if (changed)
            GlobalConfig.launcher.favouriteApps = newFavs;

        root.modelDataArray = newArr;
    }

    function launch(entry: var): void {
        if (!entry)
            return;

        const key = entry.appClass || entry.id;
        const launching = Object.assign({}, root.launchingApps);
        launching[key] = true;
        root.launchingApps = launching;

        const command = entry.runInTerminal ? [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command] : entry.command;
        Quickshell.execDetached({
            command: command,
            workingDirectory: entry.workingDirectory
        });
    }

    function focusWindow(address: string): void {
        if (!address)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${address}" })` : `focuswindow address:0x${address}`);
    }

    function closeWindow(address: string): void {
        if (!address)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${address}" })` : `closewindow address:0x${address}`);
    }

    function rebuildModel(): void {
        const apps = [];
        const pinnedIds = GlobalConfig.launcher.favouriteApps || [];

        for (const pid of pinnedIds) {
            for (const entry of DesktopEntries.applications.values) {
                if (Strings.testRegexList([pid], entry.id) && !apps.some(a => a.id === entry.id)) {
                    apps.push({
                        id: entry.id,
                        isPinned: true,
                        entry: entry,
                        toplevels: [],
                        appClass: entry.id.replace(".desktop", ""),
                        iconName: entry.id
                    });
                }
            }
        }

        for (const toplevel of Hyprland.toplevels.values) {
            const ipc = toplevel.lastIpcObject;
            if (!ipc)
                continue;

            const appClass = ipc.class || ipc.initialClass;
            if (!appClass)
                continue;

            let found = false;
            for (const app of apps) {
                const isToplevelSteamGame = appClass.toLowerCase().startsWith("steam_app_");

                if (isToplevelSteamGame) {
                    if (app.appClass.toLowerCase() === appClass.toLowerCase()) {
                        app.toplevels.push(toplevel);
                        found = true;
                        break;
                    }
                } else {
                    const isAppSteamGame = app.id.toLowerCase().startsWith("steam_app_") || app.appClass.toLowerCase().startsWith("steam_app_");
                    if (isAppSteamGame)
                        continue;

                    const baseId = app.id.toLowerCase().replace(".desktop", "");
                    if (app.appClass.toLowerCase() === appClass.toLowerCase() || app.id.toLowerCase().includes(appClass.toLowerCase()) || appClass.toLowerCase().includes(baseId)) {
                        app.toplevels.push(toplevel);
                        found = true;
                        break;
                    }
                }
            }

            if (found)
                continue;

            const isToplevelSteamGame = appClass.toLowerCase().startsWith("steam_app_");
            let entry = null;
            let iconName = appClass;

            if (isToplevelSteamGame) {
                const appId = appClass.substring(10);
                iconName = `steam_icon_${appId}`;
                entry = DesktopEntries.applications.values.find(e => e.id.toLowerCase() === `steam_app_${appId}.desktop` || e.id.toLowerCase() === `steam-${appId}.desktop`) || null;
            } else {
                entry = DesktopEntries.heuristicLookup(appClass) || null;
                if (!entry) {
                    entry = DesktopEntries.applications.values.find(e => {
                        const eBase = e.id.toLowerCase().replace(".desktop", "");
                        return e.id.toLowerCase().includes(appClass.toLowerCase()) || appClass.toLowerCase().includes(eBase);
                    }) || null;
                }
                iconName = entry ? entry.id : appClass;
            }

            apps.push({
                id: appClass,
                isPinned: false,
                entry: entry,
                toplevels: [toplevel],
                appClass: appClass,
                iconName: iconName
            });
        }

        // Drop the launching spinner once the app has a window.
        const launching = Object.assign({}, root.launchingApps);
        let launchingChanged = false;

        for (const app of apps) {
            if (app.toplevels.length === 0)
                continue;

            for (const key of [app.appClass, app.id]) {
                if (launching[key]) {
                    delete launching[key];
                    launchingChanged = true;
                }
            }
        }

        if (launchingChanged)
            root.launchingApps = launching;

        let changed = apps.length !== dockModel.count;
        if (!changed) {
            for (let i = 0; i < apps.length; i++) {
                if (apps[i].id !== dockModel.get(i).appId) {
                    changed = true;
                    break;
                }
            }
        }

        if (changed) {
            for (let i = dockModel.count - 1; i >= 0; i--) {
                if (!apps.some(app => app.id === dockModel.get(i).appId))
                    dockModel.remove(i);
            }

            for (const app of apps) {
                let found = false;
                for (let i = 0; i < dockModel.count; i++) {
                    if (dockModel.get(i).appId === app.id) {
                        found = true;
                        break;
                    }
                }
                if (!found)
                    dockModel.append({
                        appId: app.id
                    });
            }

            for (let i = 0; i < apps.length; i++) {
                if (dockModel.get(i).appId === apps[i].id)
                    continue;

                let foundIdx = -1;
                for (let j = i + 1; j < dockModel.count; j++) {
                    if (dockModel.get(j).appId === apps[i].id) {
                        foundIdx = j;
                        break;
                    }
                }
                if (foundIdx !== -1)
                    dockModel.move(foundIdx, i, 1);
            }
        }

        root.modelDataArray = apps;
        root.modelUpdateTrigger += 1;
    }

    objectName: "pluginDock"

    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight

    onModelDataArrayChanged: currentOrder = [...modelDataArray]

    onToplevelsChanged: {
        root.rebuildModel();
        delayedRebuildTimer.restart();
    }

    onActiveTopChanged: {
        root.rebuildModel();
        delayedRebuildTimer.restart();
    }

    Component.onCompleted: root.rebuildModel()

    ListModel {
        id: dockModel
    }

    Timer {
        id: delayedRebuildTimer

        interval: 100
        repeat: false

        onTriggered: root.rebuildModel()
    }

    Connections {
        function onFavouriteAppsChanged(): void {
            root.rebuildModel();
        }

        target: GlobalConfig.launcher
    }

    StyledRect {
        id: container

        readonly property var appsValues: DesktopEntries.applications.values

        color: root.modelDataArray.length > 0 ? Colours.tPalette.m3surfaceContainer : "transparent"
        radius: Tokens.rounding.full

        implicitWidth: root.horizontal ? layout.implicitWidth + root.padding * 2 : Tokens.sizes.bar.innerWidth
        implicitHeight: root.horizontal ? Tokens.sizes.bar.innerWidth : layout.implicitHeight + root.padding * 2

        onAppsValuesChanged: root.rebuildModel()

        Behavior on implicitWidth {
            enabled: root.horizontal

            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Behavior on implicitHeight {
            enabled: !root.horizontal

            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Item {
            id: layout

            anchors.centerIn: parent
            implicitWidth: listView.width
            implicitHeight: listView.height

            ListView {
                id: listView

                anchors.centerIn: parent
                width: root.horizontal ? contentWidth : Tokens.sizes.bar.innerWidth * 0.8
                height: root.horizontal ? Tokens.sizes.bar.innerWidth * 0.8 : contentHeight
                orientation: root.horizontal ? ListView.Horizontal : ListView.Vertical
                spacing: root.spacing
                interactive: false

                add: Transition {
                    NumberAnimation {
                        property: "scale"
                        from: 0
                        to: 1
                        duration: 250
                        easing.type: Easing.OutBack
                    }
                }

                remove: Transition {
                    NumberAnimation {
                        property: "scale"
                        from: 1
                        to: 0
                        duration: 250
                        easing.type: Easing.InBack
                    }
                }

                move: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                moveDisplaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                model: DelegateModel {
                    id: visualModel

                    model: dockModel
                    delegate: dockDelegate
                }
            }
        }

        Component {
            id: dockDelegate

            Item {
                id: delegateContainer

                required property int index

                readonly property var modelData: root.modelDataArray[index] ?? null

                width: root.iconSize
                height: root.iconSize
                implicitWidth: width
                implicitHeight: height

                DropArea {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small

                    onEntered: drag => {
                        const from = drag.source?.delegateIndex;
                        const to = delegateContainer.index;
                        if (from !== undefined && to !== undefined && from !== to) {
                            dockModel.move(from, to, 1);
                            const movedItem = root.currentOrder.splice(from, 1)[0];
                            root.currentOrder.splice(to, 0, movedItem);
                        }
                    }
                    onDropped: root.saveNewOrder()
                }

                Item {
                    id: delegateItem

                    readonly property bool isActive: {
                        const activeTop = Hyprland.activeToplevel;
                        if (!activeTop)
                            return false;

                        const model = delegateContainer.modelData;
                        const ipc = activeTop.lastIpcObject;
                        if (ipc && model?.appClass) {
                            const activeClass = (ipc.class || ipc.initialClass || "").toLowerCase();
                            const appId = model.appClass.toLowerCase();
                            if (activeClass && (activeClass === appId || activeClass.includes(appId) || appId.includes(activeClass)))
                                return true;
                        }

                        return (model?.toplevels ?? []).some(top => top.address && top.address === activeTop.address);
                    }

                    readonly property int windowCount: {
                        void root.modelUpdateTrigger;
                        return delegateContainer.modelData?.toplevels?.length ?? 0;
                    }

                    property int delegateIndex: delegateContainer.index

                    width: delegateContainer.width
                    height: delegateContainer.height

                    Drag.active: dragArea.held
                    Drag.source: delegateItem
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    states: State {
                        when: dragArea.held

                        ParentChange {
                            target: delegateItem
                            parent: listView
                        }

                        PropertyChanges {
                            target: delegateItem
                            opacity: 0.8
                            z: 999
                        }
                    }

                    StateLayer {
                        id: stateLayer

                        anchors.fill: parent
                        radius: Tokens.rounding.medium

                        color: delegateItem.isActive ? Colours.palette.m3onSurface : "transparent"
                        opacity: delegateItem.isActive ? 0.1 : 0

                        acceptedButtons: Qt.NoButton

                        onEntered: {
                            const state = root.popoutState;
                            if (!state || (state.hasCurrent && state.currentName === "dockcontext"))
                                return;

                            const center = root.horizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : delegateItem.mapToItem(null, 0, delegateItem.height / 2).y;
                            root.openPopout("dockhover", delegateContainer.modelData, center);
                        }
                    }

                    MouseArea {
                        id: dragArea

                        property bool held: false

                        anchors.fill: parent
                        drag.target: held ? delegateItem : null
                        drag.axis: root.horizontal ? Drag.XAxis : Drag.YAxis
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onPressed: mouse => {
                            held = true;
                            stateLayer.press(mouse.x, mouse.y);
                        }

                        onClicked: mouse => {
                            const model = delegateContainer.modelData;
                            if (!model)
                                return;

                            if (mouse.button === Qt.LeftButton) {
                                if (model.isPinned)
                                    bounceAnim.start();

                                if (model.toplevels.length > 0)
                                    root.focusWindow(model.toplevels[0].address);
                                else if (model.entry)
                                    root.launch(model.entry);
                            } else if (mouse.button === Qt.RightButton) {
                                const center = root.horizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : delegateItem.mapToItem(null, 0, delegateItem.height / 2).y;
                                root.openPopout("dockcontext", model, center);
                            }
                        }

                        onReleased: {
                            held = false;
                            delegateItem.x = 0;
                            delegateItem.y = 0;
                            root.saveNewOrder();
                        }
                    }

                    IconImage {
                        id: icon

                        anchors.centerIn: parent
                        implicitSize: Math.round((delegateItem.width || 0) * 0.7)
                        asynchronous: true
                        source: {
                            const model = delegateContainer.modelData;
                            if (model?.entry?.icon)
                                return Quickshell.iconPath(model.entry.icon, "image-missing");
                            return Quickshell.iconPath(model?.iconName, "image-missing");
                        }
                        visible: !root.recolourIcons

                        SequentialAnimation {
                            id: bounceAnim

                            NumberAnimation {
                                target: delegateItem
                                property: "scale"
                                to: 0.7
                                duration: 100
                                easing.type: Easing.OutQuad
                            }

                            NumberAnimation {
                                target: delegateItem
                                property: "scale"
                                to: 1.0
                                duration: 400
                                easing.type: Easing.OutElastic
                            }
                        }
                    }

                    ColouredIcon {
                        anchors.fill: icon
                        source: icon.source
                        colour: Colours.palette.m3secondary
                        visible: root.recolourIcons
                    }

                    Loader {
                        anchors.fill: icon
                        anchors.margins: -Tokens.padding.small
                        active: {
                            const model = delegateContainer.modelData;
                            return root.launchingApps[model?.appClass || model?.id] || false;
                        }

                        sourceComponent: CircularIndicator {
                            running: true
                            strokeWidth: 2
                        }
                    }

                    ListView {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        orientation: ListView.Horizontal
                        interactive: false
                        height: 2
                        width: contentWidth
                        model: Math.min(2, delegateItem.windowCount)

                        remove: Transition {
                            NumberAnimation {
                                property: "scale"
                                from: 1
                                to: 0
                                duration: 250
                                easing.type: Easing.InBack
                            }

                            NumberAnimation {
                                property: "y"
                                from: 0
                                to: -15
                                duration: 250
                                easing.type: Easing.InBack
                            }
                        }

                        addDisplaced: Transition {
                            NumberAnimation {
                                properties: "x,y"
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        removeDisplaced: Transition {
                            NumberAnimation {
                                properties: "x,y"
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        delegate: Rectangle {
                            required property int index

                            width: index === 0 && delegateItem.isActive ? 16 : 2
                            height: 2
                            radius: 1
                            color: delegateItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            scale: 0
                            y: -15

                            Component.onCompleted: {
                                scale = 1;
                                y = 0;
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 250
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutBack
                                }
                            }

                            Behavior on y {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
