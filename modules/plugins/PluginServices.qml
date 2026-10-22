pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Plugins

// Hosts `custom` entry points: objects that live for as long as their plugin is enabled and need
// no place in the visual shell (timers, sockets, polling, background sync). Items work too, they
// are just never shown. Use `layer`/`inputMask` desktop widgets for anything that has to appear.
//
// A loaded object may define `function onUnload(): void { ... }`; EntryPointLoader calls it before
// the object is destroyed on a reload, on disable, or on shell shutdown.
Item {
    visible: false
    width: 0
    height: 0

    Repeater {
        model: {
            CUtils.dependency(Plugins.entryPointsRevision);
            return Plugins.entryPoints(EntryPointType.Custom);
        }

        delegate: EntryPointLoader {
            required property var modelData

            entryPoint: modelData
        }
    }
}
