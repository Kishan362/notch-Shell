import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// Bottom-right notch: a vertical pill listing system tray icons. Click the
// pill to expand; click an icon to activate it (left click launches or
// focuses, which is what the app itself asks for).
//
// quickshell 0.3.1 notes (each verified against a live OBS instance):
//   - SystemTray.items is an ObjectModel, so it needs .values to iterate
//   - item.icon is a QIcon and must be handed straight to Image.source;
//     item.icon.name is undefined and produces a broken image provider
//   - item.activate() takes no arguments in this build
//   - quickshell registers org.kde.StatusNotifierWatcher itself, so no
//     external tray daemon is required
//
// Context menus come from the app itself, walked with QsMenuOpener and drawn
// by TrayMenuList.qml. See that file for the API notes.
PanelWindow {
  id: win

  readonly property real dpi: Config.dpiScale

  anchors.bottom: true
  anchors.right: true

  WlrLayershell.layer: WlrLayershell.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  property bool shown: false

  // the tray item whose native menu is open, or null for the plain list
  property var menuFor: null

  readonly property int pillW: 36 * dpi
  readonly property int pillH: 38 * dpi
  readonly property int panelW: 230 * dpi
  readonly property int panelGap: 8 * dpi
  readonly property int maxPanelH: 400 * dpi
  readonly property int headerH: 26 * dpi
  readonly property int rowH: 40 * dpi
  readonly property int padV: 16 * dpi

  readonly property var items: SystemTray.items.values

  readonly property bool menuShowing: menuFor !== null && menuFor.hasMenu

  // QsMenuOpener is what makes the item's menu layout materialise; the handle
  // on its own exposes nothing usable until something asks for the layout
  QsMenuOpener {
    id: menuOpener
    menu: win.menuFor ? win.menuFor.menu : null
  }

  FontMetrics {
    id: menuFm
    font.family: Theme.fontFamily
    font.pixelSize: 10 * win.dpi
  }

  // DBus labels carry Qt mnemonic underscores; nothing here handles
  // accelerators, so they would just show as stray marks
  function cleanMnemonic(s) {
    return String(s === undefined || s === null ? "" : s).replace(/_([^_])/g, "$1")
  }

  function menuEntries() {
    return menuOpener.children ? menuOpener.children.values : []
  }

  // Open an item's own menu. The loader is driven from here rather than from a
  // source binding so that reopening the same item rebuilds the list, and so
  // the required menuHandle property is supplied at construction.
  function openMenu(item) {
    menuFor = item
    shown = true
    if (item && item.hasMenu) {
      menuLoader.setSource(Qt.resolvedUrl("TrayMenuList.qml"),
                            { menuHandle: item.menu })
    } else {
      menuLoader.source = ""
    }
  }

  function closeMenu() {
    menuFor = null
    menuLoader.source = ""
  }

  // Height and width are summed from the entries themselves via FontMetrics.
  // Deriving the window size from the rendered column instead closes a loop
  // (window -> row -> column -> window) that gains a float epsilon per pass
  // and pins the shell at 100% CPU. TrayMenuList.qml carries the long note.
  readonly property int menuPanelH: Math.min(maxPanelH, (function() {
    // measured from the entries themselves, so the window has a size to aim
    // at before the menu is even built
    let h = 14 * dpi
    for (const e of menuEntries()) h += e.isSeparator ? 7 * dpi : 30 * dpi
    // an expanded submenu makes the real column taller than that, and the
    // panel clips, so take whichever is larger. Height depending on width is
    // fine; the reverse is the loop this file is guarding against.
    if (menuLoader.item) {
      h = Math.max(h, menuLoader.item.implicitHeight + 34 * dpi)
    }
    return h
  })())

  readonly property int menuPanelW: Math.min(320 * dpi, Math.ceil((function() {
    let w = 120 * dpi
    for (const e of menuEntries()) {
      if (e.isSeparator) continue
      w = Math.max(w, menuFm.advanceWidth(cleanMnemonic(e.text)) + 78 * dpi)
    }
    return w
  })()))

  readonly property int panelWidth: menuShowing ? menuPanelW : panelW

  readonly property int panelH: menuShowing
    ? menuPanelH
    : Math.min(headerH + items.length * rowH + padV, maxPanelH)

  implicitWidth: Math.max(pillW, panelWidth)
  implicitHeight: (shown && items.length > 0)
    ? panelH + panelGap + pillH
    : pillH

  // The pill, bottom-right, with a squared top-right corner to read as a notch.
  Rectangle {
    id: pill
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: win.pillW
    height: win.pillH
    radius: 12 * dpi
    topLeftRadius: 12 * dpi
    topRightRadius: 0
    bottomRightRadius: 0
    bottomLeftRadius: 12 * dpi
    color: pillMouse.pressed ? Theme.bg2 : Theme.bg
    border.width: 1
    border.color: Theme.borderBg3
    visible: win.items.length > 0

    // icon only. the pill appearing at all is what signals there is
    // something in the tray, so no count is needed
    Text {
      anchors.centerIn: parent
      text: "" // nf-fa-bolt
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
        // collapsing the panel drops any open menu with it
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
    anchors.right: parent.right
    width: win.panelW
    height: win.panelH
    radius: 12 * dpi
    color: Theme.bg
    border.width: 1
    border.color: Theme.borderBg3
    visible: win.shown && win.items.length > 0
    opacity: visible ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 150 } }

    // The item list and the item's own menu share this panel; only one shows.
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 8 * dpi
      spacing: 2 * dpi
      visible: !win.menuShowing

      Text {
        text: "System Tray"
        color: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: 9 * dpi
        Layout.leftMargin: 4 * dpi
        Layout.bottomMargin: 2 * dpi
      }

      Repeater {
        model: win.items
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
            spacing: 10 * dpi

            // the QIcon goes straight into source; icon.name is undefined here.
            // inside a Layout the size must be requested via Layout.*, otherwise
            // the row stretches the image out to its natural pixel size.
            Image {
              source: modelData.icon
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
              Layout.preferredWidth: 22 * dpi
              Layout.preferredHeight: 22 * dpi
              Layout.maximumWidth: 22 * dpi
              Layout.maximumHeight: 22 * dpi
            }

            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true

              Text {
                text: modelData.tooltipTitle || modelData.title || modelData.id
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 10 * dpi
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              // only shown when the app supplies a description worth the row
              Text {
                text: modelData.tooltipDescription || ""
                color: Theme.fg5
                font.family: Theme.fontFamily
                font.pixelSize: 9 * dpi
                elide: Text.ElideRight
                visible: text.length > 0
                Layout.fillWidth: true
              }
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) {
                // the app's own menu, if it has one. Items that only offer a
                // menu and do nothing on activate still get their menu here.
                if (modelData.hasMenu) win.openMenu(modelData)
              } else {
                if (modelData.activate) modelData.activate()
                win.shown = false
              }
            }
          }
        }
      }
    }

    // The app's own context menu, shown in place of the list.
    Item {
      anchors.fill: parent
      anchors.margins: 6 * dpi
      visible: win.menuShowing
      clip: true

      // back bar, so the list is one click away
      Rectangle {
        id: menuHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22 * dpi
        radius: 6 * dpi
        color: backMouse.containsMouse ? Theme.focusBgL : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 4 * dpi
          spacing: 6 * dpi

          Text {
            text: "‹"
            color: backMouse.containsMouse ? Theme.fg : Theme.fg3
            font.family: Theme.fontFamily
            font.pixelSize: 13 * dpi
            Layout.preferredWidth: 10 * dpi
          }

          Text {
            text: win.menuFor
              ? (win.menuFor.tooltipTitle || win.menuFor.title || win.menuFor.id)
              : ""
            color: Theme.fg5
            font.family: Theme.fontFamily
            font.pixelSize: 9 * dpi
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

      Loader {
        id: menuLoader
        anchors.top: menuHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: menuLoader.item ? menuLoader.item.implicitHeight : 0
        clip: true

        // loaded only through openMenu/closeMenu, which use setSource so the
        // required property is supplied at construction. Assigning it in
        // onLoaded is too late and leaves menuHandle uninitialised.
        onLoaded: {
          item.activated.connect(function() { win.closeMenu() })
        }
      }
    }
  }
}
