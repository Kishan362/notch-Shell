import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string rx: "..."
    property string tx: "..."
    // set when nusgmon itself reports a problem, so the dashboard can say so
    // instead of just leaving the "..." placeholder
    property string unavailableReason: ""

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Process {
        id: bwProc
        command: ["nusgmon", "--today", "--json"]
        running: false

        // nusgmon answers a plain-text message on stdout (not JSON) when it has
        // not been initialised yet, so only parse when it really is JSON and
        // surface the message rather than logging a JSON syntax error
        function handleOutput(raw) {
            const text = raw.trim()
            if (text === "") return
            if (text[0] !== "{" && text[0] !== "[") {
                root.unavailableReason = text.replace(/\u001b\[[0-9;]*m/g, "").trim()
                console.log("nusgmon:", root.unavailableReason)
                return
            }
            try {
                const data = JSON.parse(text)
                const unit = data.unit || "MB"
                const up   = data.total[0].up
                const down = data.total[0].down
                root.rx = down.toFixed(1) + " " + unit
                root.tx = up.toFixed(1) + " " + unit
                root.unavailableReason = ""
            } catch (e) {
                root.unavailableReason = "could not read nusgmon output"
                console.log("nusgmon parse error:", e)
            }
        }

        stdout: StdioCollector { onStreamFinished: bwProc.handleOutput(this.text) }
        stderr: StdioCollector { onStreamFinished: bwProc.handleOutput(this.text) }
    }

    Timer {
        interval: Config.dataUsageRefreshInterval
        running: box.miniDashboard
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            bwProc.running = false
            bwProc.running = true
        }
    }

    Column {
        id: col
        spacing: 2

        Text {
            text: "↓ " + root.rx
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
        }

        Text {
            text: "↑ " + root.tx
            color: Theme.fg
            opacity: 0.6
            font { family: Theme.fontFamily; pixelSize: 10 }
        }
    }
}
