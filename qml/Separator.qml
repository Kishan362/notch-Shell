import QtQuick

// Thin vertical rule for dividing groups of pill bar modules.
// Deliberately inert: no tooltip, no pointer cursor, nothing clickable.
Rectangle {
    id: sep
    implicitWidth: 1
    implicitHeight: 14 * Config.pillScale
    color: Theme.borderBg3
}
