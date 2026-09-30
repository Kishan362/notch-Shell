import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Theme picker. Lists every palette in ThemePalettes and writes the choice
// straight into config.jsonc; Config.qml watches that file, so the bar
// restyles live without a restart. Stays open on purpose so you can watch the
// bar change while you compare.
Rectangle {
  id: picker

  property bool shown: false
  visible: opacity > 0
  opacity: shown ? 1 : 0

  // "wallpaper" leads the list: it is not in the table, it is generated from
  // the current wallpaper. Listed first because it is the one that changes
  // without you touching anything.
  readonly property var themes: [ThemeDynamic.themeName].concat(ThemePalettes.names())

  // Widen the grid as the palette set grows so a large set stays browsable.
  readonly property int columns: themes.length > 30 ? 4 : (themes.length > 16 ? 3 : 2)
  readonly property int rows: Math.ceil(themes.length / columns)
  readonly property string current: String(Config.theme).toLowerCase()

  // track the bar's width so the panel always lines up with it, but never
  // squeeze the grid below a usable size. Size the panel to the row count, capped
  // so a large palette set stays on screen.
  width: Math.max(box.width * box.dpi, 400)
  height: Math.min(150 + rows * 62, 620) * box.dpi
  x: (parent.width - picker.width) / 2
  y: box.y + box.height * box.dpi + 5 * box.dpi
  color: Theme.bg
  radius: 18 * box.dpi
  border.width: 1
  border.color: Theme.borderBg3

  Behavior on opacity { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }

  // click a swatch -> persist the choice
  Process {
    id: themeWriter
    running: false
    onExited: (code) => {
      if (code !== 0)
        console.warn("theme picker: set_theme.py failed with code", code)
    }
  }

  function apply(name) {
    if (name === picker.current) return
    themeWriter.command = ["/usr/share/notch-shell/scripts/set_config.py", "theme", name]
    themeWriter.running = true
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 13 * box.dpi
    spacing: 9 * box.dpi

    RowLayout {
      Layout.fillWidth: true
      spacing: 8 * box.dpi

      Text {
        text: "Theme"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(Theme.fontSize * 1.15)
        font.bold: true
      }

      Text {
        text: picker.themes.length + " available"
        color: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(Theme.fontSize * 0.8)
      }

      // Says which generator is actually live while the wallpaper theme is
      // selected. Dynamic theming fails silently far too often: the wallpaper
      // changes, the colours do not, and nothing tells you why. Naming the
      // source turns that into something you can see and act on.
      Text {
        visible: picker.current === ThemeDynamic.themeName
        text: "source: " + ThemeDynamic.source
              + (ThemeDynamic.source === "unavailable" ? " - set a wallpaper once" : "")
        color: ThemeDynamic.source === "unavailable" ? Theme.dangerFg : Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(Theme.fontSize * 0.8)
      }

      Item { Layout.fillWidth: true }
    }

    ScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      contentWidth: availableWidth

      GridLayout {
        width: picker.width - 26 * box.dpi
        columns: picker.columns
        columnSpacing: 8 * box.dpi
        rowSpacing: 8 * box.dpi

        Repeater {
          model: picker.themes

          delegate: Rectangle {
            id: card

            required property string modelData
            required property int index

            // the wallpaper theme is generated, not tabulated
            readonly property var entry: modelData === ThemeDynamic.themeName
              ? (ThemeDynamic.entry || ThemePalettes.get("default"))
              : ThemePalettes.get(modelData)
            readonly property bool active: modelData === picker.current

            Layout.fillWidth: true
            Layout.preferredHeight: 54 * box.dpi
            radius: 11 * box.dpi
            color: active ? Theme.accent
                          : (hover.hovered ? Theme.focusBgL : Theme.bg1)
            border.width: 1
            border.color: active ? Theme.accent : Theme.borderBg3

            Behavior on color { ColorAnimation { duration: 110 } }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 7 * box.dpi
              spacing: 5 * box.dpi

              RowLayout {
                spacing: 4 * box.dpi

                Repeater {
                  model: card.entry.swatches
                  delegate: Rectangle {
                    required property string modelData
                    Layout.preferredWidth: 15 * box.dpi
                    Layout.preferredHeight: 15 * box.dpi
                    radius: 4 * box.dpi
                    color: modelData
                    border.width: 1
                    border.color: Theme.borderBg1
                  }
                }

                Item { Layout.fillWidth: true }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 4 * box.dpi

                Text {
                  text: card.entry.label
                  color: card.active ? Theme.bg : Theme.fg3
                  font.family: Theme.fontFamily
                  font.pixelSize: Math.round(Theme.fontSize * 0.85)
                  font.bold: card.active
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  visible: card.active
                  text: "✓"
                  color: Theme.bg
                  font.family: Theme.nerdFontFamily
                  font.pixelSize: Math.round(Theme.fontSize * 0.85)
                  font.bold: true
                }
              }
            }

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: picker.apply(card.modelData)
            }
          }
        }
      }
    }

    Text {
      text: "picked with SUPER + T · written to ~/.config/notch-shell/config.jsonc"
      color: Theme.fg6
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(Theme.fontSize * 0.75)
      Layout.fillWidth: true
      elide: Text.ElideRight
    }
  }
}
