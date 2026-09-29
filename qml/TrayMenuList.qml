import Quickshell
import QtQuick
import QtQuick.Layouts

// One level of a StatusNotifier (system tray) menu, drawn in the shell's own
// styling. Submenus expand inline rather than opening another window: a tray
// menu is a couple of levels deep at most, and a stack of leaning slabs
// chasing each other across the screen reads as clutter. The type nests
// itself for child levels, so this file is the whole menu.
//
// API notes, all verified against live tray items (OBS and Shelly):
//   - the item's .menu is a QsMenuHandle; it exposes no usable .menu root
//     until something asks for the layout
//   - QsMenuOpener is what asks for it. Set .menu to the handle and read
//     .children, which is an ObjectModel, so take .values
//   - a submenu entry is itself a QsMenuHandle (DBusMenuItem derives from
//     QsMenuEntry which derives from QsMenuHandle), so pointing a second
//     QsMenuOpener straight at the entry walks that level
//   - entries are activated with .triggered()
//   - .icon is a themed icon NAME string, not a QIcon, unlike
//     StatusNotifierItem.icon which is a QIcon for Image.source
Column {
  id: root

  required property var menuHandle

  // raised by any level once something has been picked, so the notch can close
  signal activated()

  readonly property real dpi: Config.dpiScale

  readonly property int rowH: 30 * dpi
  readonly property int sepH: 7 * dpi

  QsMenuOpener {
    id: opener
    menu: root.menuHandle
  }

  // DBus menus carry Qt mnemonic underscores ("_Open"). Nothing here handles
  // accelerators, so leaving them in just puts stray marks in the labels.
  function clean(s) { return String(s === undefined || s === null ? "" : s).replace(/_([^_])/g, "$1") }

  spacing: 0

  Repeater {
    model: opener.children

    delegate: Item {
      id: row
      required property var modelData
      readonly property var entry: modelData
      readonly property bool interactive: entry.enabled && !entry.isSeparator

      // width comes from the parent, never from the children. deriving the
      // window width from this Column's implicitWidth closes a loop
      // (window -> row -> column -> window) that gains a float epsilon each
      // pass and pins the shell at 100% CPU.
      width: root.width
      // the row grows by however tall its open submenu ended up
      implicitHeight: entry.isSeparator ? root.sepH : root.rowH + subLoader.height

      Rectangle {
        anchors.fill: parent
        radius: 6 * root.dpi
        color: rowMouse.containsMouse ? Theme.focusBgL : "transparent"
        visible: !row.entry.isSeparator
      }

      // separator rule
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 6 * root.dpi
        width: parent.width - 12 * root.dpi
        height: 1
        color: Theme.borderBg3
        visible: row.entry.isSeparator
      }

      // the label sits in the top slice only; an expanded submenu takes the
      // space below it, otherwise the two draw on top of each other
      RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rowH
        anchors.leftMargin: 8 * root.dpi
        anchors.rightMargin: 8 * root.dpi
        spacing: 6 * root.dpi
        visible: !row.entry.isSeparator

        // check column, for entries the app marks as checkable
        Text {
          text: row.entry.checkState !== 0 ? "✓" : ""
          color: Theme.accent
          font.family: Theme.fontFamily
          font.pixelSize: 10 * root.dpi
          Layout.preferredWidth: 12 * root.dpi
        }

        // themed icon name, when the app supplies one
        Image {
          source: row.entry.icon ? ("image:///" + row.entry.icon) : ""
          visible: row.entry.icon !== "" && row.entry.icon !== undefined
          fillMode: Image.PreserveAspectFit
          smooth: true
          Layout.preferredWidth: 16 * root.dpi
          Layout.preferredHeight: 16 * root.dpi
          Layout.maximumWidth: 16 * root.dpi
          Layout.maximumHeight: 16 * root.dpi
        }

        Text {
          text: root.clean(row.entry.text)
          color: row.entry.enabled ? Theme.fg : Theme.fg5
          font.family: Theme.fontFamily
          font.pixelSize: 10 * root.dpi
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        // chevron on entries that open a submenu
        Text {
          text: "›"
          color: Theme.fg5
          font.family: Theme.fontFamily
          font.pixelSize: 12 * root.dpi
          visible: row.entry.hasChildren
          Layout.preferredWidth: row.entry.hasChildren ? 10 * root.dpi : 0
        }
      }

      // expanded submenu, loaded by URL: QML rejects a type that instantiates
      // itself, and a menu tree is the one place recursion is the natural shape
      Loader {
        id: subLoader
        // starts just below the row's own label, so the two never overlap
        anchors.top: parent.top
        anchors.topMargin: root.rowH
        x: 8 * root.dpi
        width: parent.width - 16 * root.dpi
        height: subLoader.item ? subLoader.item.implicitHeight : 0
        clip: true
        visible: height > 0

        Behavior on height {
          NumberAnimation { duration: 120; easing.type: Easing.OutExpo }
        }

        onLoaded: item.activated.connect(root.activated)
      }

      MouseArea {
        id: rowMouse
        anchors.fill: parent
        anchors.bottomMargin: subLoader.height
        hoverEnabled: true
        enabled: row.interactive
        cursorShape: Qt.PointingHandCursor

        onClicked: {
          if (row.entry.hasChildren) {
            // expanding and collapsing are the same click; the submenu sits
            // inside this row so the window still hugs the content
            row.expanded = !row.expanded
          } else {
            row.entry.triggered()
            root.activated()
          }
        }
      }

      property bool expanded: false

      onExpandedChanged: {
        if (expanded) {
          subLoader.setSource(Qt.resolvedUrl("TrayMenuList.qml"),
                              { menuHandle: row.entry })
        } else {
          subLoader.source = ""
        }
      }
    }
  }
}
