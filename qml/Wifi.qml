import Quickshell
import Quickshell.Networking
import QtQuick

// Wi-Fi indicator only - same signal tiers as Network.qml but without the SSID
// text, for when the bar should not repeat the connection name. Use "network"
// instead if you want the name inline.
Item {
    id: root

    property string iconFg: Theme.infoFg
    property string disconIconFg: Theme.fg4

    readonly property bool wifiEnabled: Networking.wifiEnabled
    property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

    property var tetherDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected)
    readonly property bool tethered: tetherDevice !== undefined

    readonly property real signal: active ? active.signalStrength * 100 : 0

    readonly property string icon: {
        if (root.tethered) return String.fromCodePoint(0xf287) // nf-fa-usb
        if (!Networking.wifiEnabled) return String.fromCodePoint(0xf092d)
        if (!root.active) return String.fromCodePoint(0xf092d)
        let s = root.signal / 100
        let tier = s >= 0.75 ? 4
                 : s >= 0.50 ? 3
                 : s >= 0.25 ? 2
                 : 1
        return String.fromCodePoint(0xf091f + (tier - 1) * 3)
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.icon
        color: root.tethered ? root.iconFg : (Networking.wifiEnabled ? root.iconFg : root.disconIconFg)
        font.family: Theme.nerdFontFamily
        font.pixelSize: 10 * Config.pillScale
    }
}
