pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components.controls
import qs.services

// Opens the launcher's wallpaper picker. Styled like the shell's non-toggle quick toggles
// (`settings`, `vpn` when it cannot toggle): same container colour, only the icon colour is
// overridden because a non-toggle button would otherwise use the filled on-primary colour.
IconButton {
    id: root

    fillWidth: true
    shapeMorph: true

    icon: "wallpaper"
    isToggle: false
    isRound: true

    inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
    inactiveOnColour: Colours.palette.m3onSurfaceVariant

    onClicked: {
        ShellState.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}wallpaper `;
        const state = ShellState.forActive();
        if (state) {
            state.utilities = false;
            state.launcher = true;
        }
    }
}
