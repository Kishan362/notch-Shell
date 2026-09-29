import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: weatherPopup

  readonly property color tileBg: Theme.bg1
  readonly property int tileRadius: 11
  readonly property color dividerColor: Theme.borderBg2
  readonly property color labelText: Theme.fg5
  readonly property color valueText: Theme.fg
  readonly property color secondaryText: Theme.fg3
  readonly property color headerText: Theme.fg2
  readonly property int iconSizeMedium: 13
  readonly property int iconSizeForecast: 16
  readonly property int fontSizeTiny: 8
  readonly property int fontSizeSmall: 9
  readonly property int fontSizeBody: 9
  readonly property int tileSpacing: 8

  property bool shown: false
  // location editor state
  property bool editing: false
  property string searchText: ""
  readonly property bool searchActive: editing || WeatherModule.geoResults.length > 0
  visible: opacity > 0.01
  opacity: shown ? 1 : 0
  width: 280 * box.dpi
  height: contentCol.implicitHeight + 26 * box.dpi
  x: (Screen.width - weatherPopup.width) / 2
  y: box.y + box.height * box.dpi + 5 * box.dpi
  color: Theme.bgD
  radius: 20 * box.dpi

  Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

  // debounce so typing does not fire a request per keystroke
  Timer {
    id: searchDebounce
    interval: 320
    onTriggered: WeatherModule.geoSearch(weatherPopup.searchText)
  }

  Process {
    id: configWriter
    running: false
    onExited: (code) => {
      if (code !== 0) console.warn("weather picker: set_config.py failed", code)
      else WeatherModule.refresh()
    }
  }

  // Persist the pick: a readable name for the UI, coordinates for the API, so
  // later fetches never have to re-guess which "Delhi" was meant.
  function pick(r) {
    if (!r || r.lat === undefined || r.lon === undefined) return
    const label = r.country ? r.name + ", " + r.country : r.name
    const coords = r.lat.toFixed(4) + "," + r.lon.toFixed(4)
    // one atomic write: a readable name for the UI, coordinates for the API, so
    // later fetches never have to re-guess which "Delhi" was meant
    configWriter.command = ["/usr/share/notch-shell/scripts/set_config.py",
                            "weatherLocation", label,
                            "weatherQuery", coords]
    configWriter.running = true
    closeEditor()
  }

  function closeEditor() {
    editing = false
    searchText = ""
    searchDebounce.stop()
    WeatherModule.clearGeo()
  }

  // column containing city/location and refresh button
  ColumnLayout {
    id: contentCol
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 14 * box.dpi
    spacing: 10 * box.dpi

    RowLayout {
      Layout.fillWidth: true

      Text {
        id: cityLabel
        visible: !weatherPopup.searchActive
        text: WeatherModule.locationLabel
        color: cityHover.containsMouse ? Theme.accent : weatherPopup.headerText
        font.family: Theme.fontFamily
        font.pixelSize: 12 * box.dpi
        font.weight: 500
        Layout.leftMargin: 3 * box.dpi
        Layout.fillWidth: true
        elide: Text.ElideRight
        MouseArea {
          id: cityHover
          anchors.fill: parent
          anchors.margins: -2 * box.dpi
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            weatherPopup.editing = true
            weatherPopup.searchText = ""
            WeatherModule.clearGeo()
            Qt.callLater(() => cityInput.forceActiveFocus())
          }
        }
      }

      // active while searching, or while a search/detect has results to show
      RowLayout {
        id: editorRow
        visible: weatherPopup.searchActive
        Layout.fillWidth: true
        Layout.leftMargin: 3 * box.dpi
        spacing: 6 * box.dpi

        TextField {
          id: cityInput
          Layout.fillWidth: true
          implicitHeight: 22 * box.dpi
          placeholderText: WeatherModule.geoSearching ? "searching..." : "search city..."
          text: weatherPopup.searchText
          color: Theme.fg
          placeholderTextColor: Theme.fg6
          font.family: Theme.fontFamily
          font.pixelSize: 11 * box.dpi
          selectByMouse: true
          background: Rectangle {
            radius: 6 * box.dpi
            color: Theme.bg5
            border.width: 1
            border.color: cityInput.activeFocus ? Theme.borderBgFocus : Theme.borderBg3
          }
          onTextChanged: {
            weatherPopup.searchText = text
            searchDebounce.restart()
          }
          onAccepted: {
            // enter picks the first result, if any
            if (WeatherModule.geoResults.length > 0)
              weatherPopup.pick(WeatherModule.geoResults[0])
          }
          Keys.onEscapePressed: weatherPopup.closeEditor()
        }

        Text {
          id: detectBtn
          text: "\uf1e0"                      // nf-fa-crosshairs / locate
          color: detectHover.containsMouse ? Theme.accent : Theme.fg5
          font.family: Theme.nerdFontFamily
          font.pixelSize: 12 * box.dpi
          MouseArea {
            id: detectHover
            anchors.fill: parent
            anchors.margins: -5 * box.dpi
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: WeatherModule.detectLocation()
          }
        }

        Text {
          text: "\uf00d"                      // nf-fa-check
          color: detectHover.containsMouse ? Theme.accent : Theme.fg5
          font.family: Theme.nerdFontFamily
          font.pixelSize: 12 * box.dpi
          MouseArea {
            anchors.fill: parent
            anchors.margins: -5 * box.dpi
            cursorShape: Qt.PointingHandCursor
            onClicked: WeatherModule.clearGeo()
          }
        }
      }

      Text {
        text: "\uead2"
        color: refreshHover.containsMouse ? Theme.focusFg : Theme.fg7
        font.family: Config.nerdFontFamily
        font.pixelSize: 13 * box.dpi
        Behavior on color { ColorAnimation { duration: 100 } }
        MouseArea {
          id: refreshHover
          anchors.fill: parent
          anchors.margins: -6 * box.dpi
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: WeatherModule.refresh()
        }
      }
    }

    // search / detect results
    ColumnLayout {
      id: geoCol
      visible: weatherPopup.searchActive
      Layout.fillWidth: true
      spacing: 2 * box.dpi

      Repeater {
        model: WeatherModule.geoResults
        delegate: Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 24 * box.dpi
          radius: 7 * box.dpi
          color: geoHover.containsMouse ? Theme.focusBgL : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 7 * box.dpi
            anchors.rightMargin: 7 * box.dpi
            spacing: 6 * box.dpi

            Text {
              text: modelData.name
              color: Theme.fg
              font.family: Theme.fontFamily
              font.pixelSize: 10 * box.dpi
              elide: Text.ElideRight
              Layout.maximumWidth: 78 * box.dpi
            }
            Text {
              text: modelData.country
              color: Theme.fg5
              font.family: Theme.fontFamily
              font.pixelSize: 9 * box.dpi
              elide: Text.ElideRight
              Layout.maximumWidth: 84 * box.dpi
            }
            Text {
              text: modelData.admin
              color: Theme.fg6
              font.family: Theme.fontFamily
              font.pixelSize: 9 * box.dpi
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          MouseArea {
            id: geoHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: weatherPopup.pick(modelData)
          }
        }
      }

      Text {
        visible: WeatherModule.geoError !== "" && WeatherModule.geoResults.length === 0
        text: WeatherModule.geoError
        color: Theme.warning
        font.family: Theme.fontFamily
        font.pixelSize: 9 * box.dpi
        Layout.leftMargin: 7 * box.dpi
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 16 * box.dpi

      Text {
        text: WeatherModule.iconGlyph
        color: WeatherModule.iconColor
        font.family: Config.nerdFontFamily
        font.pixelSize: 32 * box.dpi
        Layout.preferredWidth: 45 * box.dpi
        horizontalAlignment: Text.AlignHCenter
      }

      ColumnLayout {
        spacing: 1 * box.dpi
        Layout.fillWidth: true
        Text {
          text: WeatherModule.loading ? "..."
              : WeatherModule.isError ? "!"
              : Math.round(WeatherModule.temp) + "°" + (Config.weatherUnits === "metric" ? "C" : "F")
          color: WeatherModule.isError ? Theme.warning : Theme.fg2
          font.family: WeatherModule.isError ? Config.nerdFontFamily : Theme.fontFamily
          font.pixelSize: 25 * box.dpi
          font.weight: 500
        }
        Text {
          text: WeatherModule.condition
          color: Theme.fg5
          font.family: Theme.fontFamily
          font.pixelSize: weatherPopup.fontSizeBody * box.dpi
          font.weight: 400
          visible: !WeatherModule.loading && WeatherModule.errorMessage.length === 0
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }

    // stat tiles
    RowLayout {
      Layout.fillWidth: true
      spacing: weatherPopup.tileSpacing * box.dpi
      visible: !WeatherModule.loading && WeatherModule.errorMessage.length === 0

      Repeater {
        model: [
          { icon: "\ue34e", color: "#f18d41", value: Math.round(WeatherModule.feelsLike) + "°", label: "Feels" },
          { icon: "\ue373", color: "#5f99fa", value: WeatherModule.humidity + "%", label: "Humidity" },
          { icon: "\ue34b", color: "#54e04b", value: Math.round(WeatherModule.windSpeed) + " km/h", label: "Wind" }
        ]
        delegate: Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 62 * box.dpi
          radius: weatherPopup.tileRadius * box.dpi
          color: statHover.containsMouse ? Qt.lighter(weatherPopup.tileBg, 1.25) : weatherPopup.tileBg
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: statHover
            anchors.fill: parent
            hoverEnabled: true
          }

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 3 * box.dpi

            Text {
              text: modelData.icon
              color: modelData.color
              font.family: Config.nerdFontFamily
              font.pixelSize: weatherPopup.iconSizeMedium * box.dpi
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: modelData.value
              color: weatherPopup.valueText
              font.family: Theme.fontFamily
              font.pixelSize: weatherPopup.fontSizeBody * box.dpi
              font.weight: 600
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: modelData.label
              color: weatherPopup.labelText
              font.family: Theme.fontFamily
              font.pixelSize: weatherPopup.fontSizeTiny * box.dpi
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1 * box.dpi; color: weatherPopup.dividerColor }

    // sunrise and sunset
    RowLayout {
      Layout.fillWidth: true
      spacing: 0
      visible: !WeatherModule.loading && WeatherModule.errorMessage.length === 0

      RowLayout {
        spacing: 5 * box.dpi

        Text {
          text: "\ue34c"
          color: "#ffcd58"
          font.family: Config.nerdFontFamily
          font.pixelSize: weatherPopup.iconSizeMedium * box.dpi
          Layout.leftMargin: 10 * box.dpi
        }

        Text {
          text: WeatherModule.sunrise
          color: weatherPopup.secondaryText
          font.family: Theme.fontFamily
          font.pixelSize: weatherPopup.fontSizeSmall * box.dpi
        }
      }

      Item { Layout.fillWidth: true }

      RowLayout {
        Text {
          text: "\ue34d"
          color: "#ff904d"
          font.family: Config.nerdFontFamily
          font.pixelSize: weatherPopup.iconSizeMedium * box.dpi
        }

        Text {
          text: WeatherModule.sunset
          color: weatherPopup.secondaryText
          font.family: Theme.fontFamily
          font.pixelSize: weatherPopup.fontSizeSmall * box.dpi
          Layout.rightMargin: 10 * box.dpi
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1 * box.dpi; color: weatherPopup.dividerColor }

    // forecast
    RowLayout {
      Layout.fillWidth: true
      spacing: weatherPopup.tileSpacing * box.dpi

      Repeater {
        model: WeatherModule.forecast
        delegate: ColumnLayout {
          Layout.fillWidth: true
          spacing: 5 * box.dpi

          Text {
            text: Qt.formatDate(new Date(modelData.date), "ddd")
            color: Theme.fg5
            font.family: Theme.fontFamily
            font.pixelSize: weatherPopup.fontSizeTiny * box.dpi
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: modelData.iconGlyph
            color: modelData.iconColor
            font.family: Config.nerdFontFamily
            font.pixelSize: weatherPopup.iconSizeForecast * box.dpi
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: Math.round(modelData.maxTemp) + "°/" + Math.round(modelData.minTemp) + "°"
            color: Theme.fg5
            font.family: Theme.fontFamily
            font.pixelSize: weatherPopup.fontSizeTiny * box.dpi
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }

    // last time weather updated
    Text {
      text: "Updated at " + Qt.formatTime(WeatherModule.lastUpdated, "hh:mm")
      color: Theme.fg5
      font.family: Theme.fontFamily
      font.pixelSize: weatherPopup.fontSizeTiny * box.dpi
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 2 * box.dpi
    }
  }
}
