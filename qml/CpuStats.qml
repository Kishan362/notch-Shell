import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// CPU readout for the mini dashboard, replacing the old data-usage block.
//
// Usage comes from /proc/stat read through a FileView, so a refresh costs one
// small read rather than a process spawn. Percentages are deltas between
// samples: the counters in /proc/stat are monotonic jiffies since boot, so a
// raw ratio would only report uptime.
//
// Temperature comes from lm_sensors and is optional. `sensors` may not be
// installed, and the readout then hides the temperature rather than showing a
// dash. Temps move slowly, so it is polled far less often than usage.
Item {
  id: root

  property real refreshMs: 2000
  property int tempRefreshMs: 10000

  // null until the second sample lands; a percentage needs a delta to exist
  property real overall: -1
  property var cores: []
  property real tempC: -1
  property bool tempSupported: false

  // left or right click opens the per-core list
  property bool detailOpen: false

  // previous jiffies per cpu, keyed "all", "0", "1", ...
  property var _prev: ({})

  // width/height, not just implicit*: a ColumnLayout fills whatever box it is
  // given, and the dashboard places this item with anchors only, so leaving the
  // size at 0 collapsed the layout and drew the rows on top of each other.
  // The dependency is one way — the children keep their own implicit widths —
  // so this does not feed back.
  width: col.width
  height: col.height
  implicitWidth: col.width
  implicitHeight: col.height

  function _sum(vals) {
    let t = 0
    for (let i = 0; i < vals.length; i++) t += vals[i]
    return t
  }

  function _pct(key, fields) {
    // guest and guest_nice are already counted inside user/nice, so stop at steal
    const total = _sum(fields.slice(0, 8))
    const idle = fields[3] + fields[4]
    const p = root._prev[key]
    root._prev[key] = { total: total, idle: idle }
    // no previous sample, or no time has passed: nothing to compute yet
    if (!p || total <= p.total) return -1
    const dTotal = total - p.total
    const dIdle = idle - p.idle
    const pct = (1 - dIdle / dTotal) * 100
    return Math.max(0, Math.min(100, pct))
  }

  FileView {
    id: statView
    path: "/proc/stat"
    blockLoading: false
    printErrors: false

    onLoaded: {
      const lines = statView.text().split("\n")
      const perCore = []

      for (const line of lines) {
        if (line.indexOf("cpu ") === 0) {
          root.overall = root._pct("all", line.trim().split(/\s+/).slice(1).map(Number))
        } else if (/^cpu\d+ /.test(line)) {
          const parts = line.trim().split(/\s+/)
          const idx = parts[0].slice(3)
          const pct = root._pct(idx, parts.slice(1).map(Number))
          if (pct >= 0) perCore.push({ name: "CPU " + idx, pct: pct })
        }
      }

      if (perCore.length) root.cores = perCore
    }
  }

  Timer {
    interval: root.refreshMs
    // only poll while the dashboard is actually on screen
    running: box.miniDashboard
    repeat: true
    triggeredOnStart: true
    onTriggered: statView.reload()
  }

  // temperature, via lm_sensors
  Process {
    id: sensorsProc
    command: ["sh", "-c", "sensors 2>/dev/null"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        const t = this.text
        // prefer the package sensor, fall back to the first core
        let m = t.match(/Package id\s+\d+:\s+\+?([\d.]+)/)
        if (!m) m = t.match(/Core\s+\d+:\s+\+?([\d.]+)/)
        if (m) {
          root.tempC = parseFloat(m[1])
          root.tempSupported = true
        } else {
          root.tempSupported = false
          root.tempC = -1
        }
        sensorsProc.running = false
      }
    }
    stderr: StdioCollector { onStreamFinished: sensorsProc.running = false }
  }

  Timer {
    interval: root.tempRefreshMs
    running: box.miniDashboard
    repeat: true
    triggeredOnStart: true
    onTriggered: { sensorsProc.running = false; sensorsProc.running = true }
  }

  // The dashboard is only about 125px tall here and this module hangs off the
  // bottom of it, so a fixed row count overflows the top and the summary line
  // gets clipped away. Derive the cap from the space actually available:
  // the summary, the gap and the overflow line come off the top, whatever is
  // left divided by the row height.
  readonly property int rowH: 11
  readonly property int chromeH: 13 + 2 + 11 + 2
  // how far the module sits above the dashboard's bottom edge, to clear the
  // power row. shell.qml anchors with the same value, so the two cannot drift.
  readonly property int bottomInset: 42
  // The room is what is left *below* the inset. Measuring parent.height alone
  // overstates it by the inset, which pushed the summary line off the top of
  // the dashboard entirely.
  readonly property int availH: parent && parent.height > 0
    ? parent.height - bottomInset - 4 : 120
  readonly property int maxCores: Math.max(2, Math.min(cores.length,
    Math.floor((availH - chromeH) / rowH)))
  readonly property var shownCores: cores.slice(0, maxCores)

  function fmt(p) { return p < 0 ? "--" : Math.round(p) + "%" }
  function tempText() { return tempSupported ? Math.round(tempC) + "°C" : "" }

  // Plain Column with explicitly sized rows rather than nested Layouts.
  // The dashboard places this item with anchors only and no size, so a
  // ColumnLayout ends up filling a zero-height box and the rows draw on top of
  // each other. Explicit geometry is dull but it behaves.
  readonly property int rowW: 132

  Column {
    id: col
    spacing: 2

    // summary line. a content-sized Row anchored right, rather than three
    // separately anchored Texts, so the spacing stays with the row
    Item {
      width: root.rowW
      height: 13

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
          text: "\uf19b"
          color: Theme.fg
          font { family: Theme.nerdFontFamily; pixelSize: 10 }
        }

        Text {
          text: root.fmt(root.overall)
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
        }

        // only rendered when lm_sensors gave us something
        Text {
          text: root.tempText()
          color: Theme.fg
          opacity: 0.6
          visible: root.tempSupported
          font { family: Theme.fontFamily; pixelSize: 10 }
        }
      }
    }

    // per-core rows, revealed by the click handler below
    Repeater {
      model: root.detailOpen ? root.shownCores : []

      delegate: Item {
        required property var modelData
        width: root.rowW
        height: root.rowH

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.name
          color: Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 9 }
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: Math.round(modelData.pct) + "%"
          color: Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 9 }
        }

        // track plus fill. fixed 90px so a spike cannot resize the dashboard
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 30
          anchors.verticalCenter: parent.verticalCenter
          width: 60
          height: 4
          radius: 2
          color: Theme.bg1

          Rectangle {
            width: parent.width * Math.max(0, Math.min(100, modelData.pct)) / 100
            height: parent.height
            radius: parent.radius
            color: modelData.pct > 85 ? Theme.dangerFg : Theme.accent
          }
        }
      }
    }

    // a 16-core box would otherwise run off the top of the dashboard
    Text {
      width: root.rowW
      horizontalAlignment: Text.AlignRight
      visible: root.detailOpen && root.shownCores.length < root.cores.length
      text: "+" + (root.cores.length - root.shownCores.length) + " more"
      color: Theme.fg5
      font { family: Theme.fontFamily; pixelSize: 9 }
    }
  }

  MouseArea {
    id: cpuMouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      // both buttons work; right click is the documented gesture
      if (root.cores.length) root.detailOpen = !root.detailOpen
    }
  }
}
