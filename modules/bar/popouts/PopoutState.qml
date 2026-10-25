import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property string currentSection

    signal detachRequested(mode: string)
}
