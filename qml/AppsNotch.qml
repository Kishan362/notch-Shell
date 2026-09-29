import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Bottom-left notch: a vertical pill listing every open window, taskbar style.
// The focused window is included and marked with a dot, so you can see at a
// glance what is in front. Click the pill to expand; click a row to focus.
// Right click a row for a menu of window actions.
//
// quickshell 0.3.1 notes (each of these was verified against a live shell):
//   - windows are in Hyprland.toplevels, and it is an ObjectModel, so it
//     needs .values before it can be iterated
//   - Hyprland.activeToplevel is always null in this build, and so is
//     HyprlandToplevel.activated; Toplevel.wayland.activated is the one
//     that actually tracks focus
//   - .lastIpcObject is a snapshot taken at startup and never refreshed, so
//     it cannot be used to label float/pin state. The .wayland properties
//     are live and are used wherever a current value matters
//   - the list fills in asynchronously about a second after start
//
// Hyprland 0.56.2 notes:
//   - `hyprctl dispatch` is a Lua wrapper here, so the classic
//     `floatwindow address:0x...` form fails. The working form is
//     hl.dsp.window.<verb>({ address = "0x..." })
//   - there is no minimize dispatcher, and no move-to-workspace dispatcher
//     under hl.dsp.window.*, hl.dsp.workspace.* or hl.dsp.toplevel.*, so
//     neither is offered in the menu
PanelWindow {
  id: win

  readonly property real dpi: Config.dpiScale

  anchors.bottom: true
  anchors.left: true

  WlrLayershell.layer: WlrLayershell.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  property bool shown: false

  // the group whose menu is open, or null for the plain list
  property var menuFor: null

  readonly property int pillW: 36 * dpi
  readonly property int pillH: 38 * dpi
  readonly property int panelW: 230 * dpi
  readonly property int panelGap: 8 * dpi
  readonly property int maxPanelH: 400 * dpi
  readonly property int headerH: 26 * dpi
  readonly property int rowH: 38 * dpi
  readonly property int menuRowH: 34 * dpi
  readonly property int padV: 16 * dpi

  readonly property bool menuShowing: menuFor !== null && menuToplevel() !== null

  readonly property int panelH: menuShowing
    ? headerH + menuItems.length * menuRowH + padV
    : Math.min(headerH + groups.length * rowH + padV, maxPanelH)

  // tightly hug the content so the transparent window never eats clicks
  implicitWidth: Math.max(pillW, panelW)
  implicitHeight: (shown && groups.length > 0)
    ? panelH + panelGap + pillH
    : pillH

  // title handed to wl-copy
  property string clipText: ""

  // Menu entries. Float and pin are deliberately worded as toggles: the only
  // source for that state is lastIpcObject, which is a startup snapshot and
  // still reports the old value after the window has been changed. Fullscreen
  // comes from .wayland.fullscreen, which is live, so it can be labelled
  // precisely.
  readonly property var menuItems: menuShowing ? [
    { label: "Focus", act: "focus" },
    { label: "Float / unfloat", act: "float" },
    { label: "Pin / unpin", act: "pin" },
    { label: (menuToplevel() && menuToplevel().wayland
              && menuToplevel().wayland.fullscreen)
              ? "Exit fullscreen" : "Enter fullscreen", act: "fullscreen" },
    { label: "Copy title", act: "copy" },
    { label: "Close window", act: "close", danger: true }
  ] : []

  // Every open window, grouped by app so three kitty windows read as one
  // row with a count. Reactive: re-runs on window and focus changes.
  property var groups: {
    const byClass = new Map()

    for (const t of Hyprland.toplevels.values) {
      const wl = t.wayland
      if (!wl) continue
      // negative workspace id means a special workspace (scratchpad, magic...)
      if (t.workspace && t.workspace.id < 1) continue

      const cls = (wl.appId || "").toLowerCase()
      if (!cls) continue

      if (!byClass.has(cls)) {
        byClass.set(cls, { cls: cls, count: 0, title: "", toplevel: null, active: false })
      }
      const g = byClass.get(cls)
      g.count++
      if (wl.activated) g.active = true
      // prefer the focused window of this app as the click target,
      // otherwise fall back to the first one seen
      if (!g.toplevel || wl.activated) {
        g.toplevel = t
        g.title = wl.title || cls
      }
    }

    return Array.from(byClass.values()).sort((a, b) => {
      // focused app first, then alphabetical
      if (a.active !== b.active) return a.active ? -1 : 1
      return a.cls.localeCompare(b.cls)
    })
  }

  // the live toplevel behind the open menu, or null if it has gone away
  function menuToplevel() {
    if (menuFor === null) return null
    const t = menuFor.toplevel
    if (!t) return null
    try {
      return t.wayland ? t : null
    } catch (e) {
      return null
    }
  }

  function openMenu(g) {
    menuFor = g
    shown = true
  }

  function closeMenu() {
    menuFor = null
  }

  function runAction(act) {
    const t = menuToplevel()

    if (act === "back" || !t) { closeMenu(); return }

    const addr = t.address
    // Lua-wrapped dispatcher syntax; the legacy form does not work here
    const dsp = verb => Hyprland.dispatch('hl.dsp.window.' + verb + '({ address = "' + addr + '" })')

    switch (act) {
      case "focus":       t.wayland.activate(); closeMenu(); break
      case "float":       dsp("float"); closeMenu(); break
      case "pin":         dsp("pin"); closeMenu(); break
      case "fullscreen":  dsp("fullscreen"); closeMenu(); break
      case "copy":
        win.clipText = t.wayland.title || menuFor.cls || ""
        clipProc.running = false
        clipProc.running = true
        closeMenu()
        break
      case "close":       t.wayland.close(); closeMenu(); break
      default:            closeMenu()
    }

    // pull a fresh window list. this refreshes the list itself, but not the
    // float/pin labels, which stay a startup snapshot either way
    Hyprland.refreshToplevels()
  }

  function focusGroup(g) {
    if (!g || !g.toplevel || !g.toplevel.wayland) return
    // already focused: do nothing, so the click cannot bounce focus
    if (g.toplevel.wayland.activated) { win.shown = false; return }
    g.toplevel.wayland.activate()
    win.shown = false
  }

  // one-shot helper behind the Copy title action
  Process {
    id: clipProc
    command: ["wl-copy", win.clipText]
    running: false
  }


  // The pill, bottom-left, with a squared top-left corner to read as a notch.
  Rectangle {
    id: pill
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    width: win.pillW
    height: win.pillH
    radius: 12 * dpi
    // square the corner nearest the screen edge
    topLeftRadius: 0
    topRightRadius: 12 * dpi
    bottomRightRadius: 12 * dpi
    bottomLeftRadius: 0
    color: pillMouse.pressed ? Theme.bg2 : Theme.bg
    border.width: 1
    border.color: Theme.borderBg3
    visible: win.groups.length > 0

    // icon only. the pill appearing at all is what signals there is
    // something running, so no count is needed
    Text {
      anchors.centerIn: parent
      text: "" // nf-fa-th
      color: Theme.fg
      font.family: Theme.nerdFontFamily
      font.pixelSize: 14 * dpi
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        // collapsing the panel drops the menu with it
        if (win.shown) win.closeMenu()
        win.shown = !win.shown
      }
    }
  }

  // Expanded list, growing upward from the pill.
  Rectangle {
    id: panel
    anchors.bottom: pill.top
    anchors.bottomMargin: win.panelGap
    anchors.left: parent.left
    width: win.panelW
    height: win.panelH
    radius: 12 * dpi
    color: Theme.bg
    border.width: 1
    border.color: Theme.borderBg3
    visible: win.shown && win.groups.length > 0
    opacity: visible ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 150 } }

    // The list and the menu share this panel; only one is ever visible.
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 8 * dpi
      spacing: 2 * dpi
      visible: !win.menuShowing

      Text {
        text: "Running Apps"
        color: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: 9 * dpi
        Layout.leftMargin: 4 * dpi
        Layout.bottomMargin: 2 * dpi
      }

      Repeater {
        model: win.groups
        delegate: Rectangle {
          id: row
          required property var modelData

          Layout.fillWidth: true
          Layout.preferredHeight: win.rowH - 2 * dpi
          radius: 8 * dpi
          color: rowMouse.containsMouse ? Theme.focusBgL : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8 * dpi
            anchors.rightMargin: 8 * dpi
            spacing: 8 * dpi

            // active-window dot
            Rectangle {
              width: 6 * dpi; height: 6 * dpi; radius: width / 2
              color: modelData.active ? Theme.accent : "transparent"
              Layout.preferredWidth: 6 * dpi
            }

            Text {
              text: modelData.cls.substring(0, 2).toUpperCase()
              color: modelData.active ? Theme.fg : Theme.fg3
              font.family: Theme.fontFamily
              font.pixelSize: 10 * dpi
              font.bold: true
              Layout.preferredWidth: 20 * dpi
            }

            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true

              Text {
                text: modelData.cls
                color: modelData.active ? Theme.fg : Theme.fg3
                font.family: Theme.fontFamily
                font.pixelSize: 10 * dpi
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: modelData.title
                color: Theme.fg5
                font.family: Theme.fontFamily
                font.pixelSize: 9 * dpi
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            // window count badge, only when the app has more than one
            Text {
              text: modelData.count > 1 ? modelData.count : ""
              color: Theme.fg5
              font.family: Theme.fontFamily
              font.pixelSize: 9 * dpi
              Layout.preferredWidth: 14 * dpi
              horizontalAlignment: Text.AlignRight
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) win.openMenu(modelData)
              else win.focusGroup(modelData)
            }
          }
        }
      }
    }

    // Right-click menu, shown in place of the list for the chosen app.
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 8 * dpi
      spacing: 2 * dpi
      visible: win.menuShowing

      // the header doubles as the back button
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: win.headerH
        radius: 8 * dpi
        color: backMouse.containsMouse ? Theme.focusBgL : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 4 * dpi
          anchors.rightMargin: 6 * dpi
          spacing: 6 * dpi

          Text {
            text: "‹"
            color: backMouse.containsMouse ? Theme.fg : Theme.fg3
            font.family: Theme.fontFamily
            font.pixelSize: 13 * dpi
            Layout.preferredWidth: 10 * dpi
          }

          Text {
            text: win.menuFor ? win.menuFor.cls : ""
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 10 * dpi
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: backMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: win.closeMenu()
        }
      }

      Repeater {
        model: win.menuItems
        delegate: Rectangle {
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: win.menuRowH
          radius: 8 * dpi
          color: itemMouse.containsMouse ? Theme.focusBgL : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10 * dpi
            anchors.right: parent.right
            anchors.rightMargin: 10 * dpi
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: modelData.danger ? Theme.dangerFg : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 10 * dpi
            elide: Text.ElideRight
          }

          MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.runAction(modelData.act)
          }
        }
      }
    }
  }
}
