import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property string currentSection
    // The item a plugin dock shows in its hover/context popout. Only used by `dockhover` and
    // `dockcontext`; a bar entry sets it before opening one of those.
    property var dockModel: null

    signal detachRequested(mode: string)
}
