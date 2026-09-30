import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Notifications

ShellRoot {
  id: shellRoot

  IpcHandler {
      target: "cliphist"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = !box.cliphistOpen; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = true; box.powerMenu = false; box.themePicker = false }
      function hide(): void { box.cliphistOpen = false }
  }

  IpcHandler {
      target: "controlCenter"
      function toggle(): void { box.controlCenter = !box.controlCenter; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
      function show(): void { box.controlCenter = true; box.miniDashboard = false; box.cliphistOpen = false; box.powerMenu = false; box.themePicker = false }
      function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
      target: "miniDashboard"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = !box.miniDashboard; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = true; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
      function hide(): void { box.miniDashboard = false }
  }

  IpcHandler {
    target: "appLauncher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = !box.appLauncher; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = true; box.powerMenu = false; box.themePicker = false }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "wallpaperSwitcher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = !box.wallpaperSwitcherOpen; box.powerMenu = false; box.themePicker = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = true; box.powerMenu = false; box.themePicker = false }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "powerMenu"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenu = !box.powerMenu; if (!box.powerMenu) box.powerMenuInitialAction = ""; box.themePicker = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenu = true; box.themePicker = false }
    function hide(): void { box.powerMenu = false; box.powerMenuInitialAction = "" }
  }

  Shortcut {
    sequence: "Escape"
    onActivated: shellRoot.dismissOverlays()
  }

  IpcHandler {
    target: "weather"
    // note: the loader's onLoaded already sets shown = true, so activating it
    // must not also toggle - that would flip it straight back off
    function toggle(): void {
      if (!weatherPopupLoader.active)
        weatherPopupLoader.active = true
      else if (weatherPopupLoader.item)
        weatherPopupLoader.item.shown = !weatherPopupLoader.item.shown
      calendarPopup.shown = false
    }
    function show(): void {
      if (!weatherPopupLoader.active) weatherPopupLoader.active = true
      else if (weatherPopupLoader.item) weatherPopupLoader.item.shown = true
      calendarPopup.shown = false
    }
    function hide(): void { if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false }
  }

  IpcHandler {
    target: "themePicker"
    function toggle(): void {
      box.themePicker = !box.themePicker
      if (box.themePicker) {
        box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false
        box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false
      }
    }
    function show(): void {
      box.themePicker = true
      box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false
      box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false
    }
    function hide(): void { box.themePicker = false }
  }

  // Escape closes whatever overlay is open.
  //
  // cliphist, the app launcher and the power menu are deliberately absent:
  // they already handle Escape in their own Keys handlers, and the power menu
  // needs its two-stage behaviour (first Escape cancels a pending
  // confirmation, the second closes). Touching them here would discard that
  // pending action.
  function dismissOverlays() {
    // step back one level first: if the location editor is open, Escape cancels
    // the edit and leaves the popup up, rather than closing everything at once
    const wp = weatherPopupLoader.item
    if (wp && wp.editing) { wp.closeEditor(); return }
    if (wp) wp.shown = false
    if (calendarPopup) calendarPopup.shown = false
    box.controlCenter = false
    box.miniDashboard = false
    box.themePicker = false
    box.wallpaperSwitcherOpen = false
  }

  function capitalize(str) {
      return str.charAt(0).toUpperCase() + str.slice(1)
  }

  property bool pillHoverActive: false

  // ---- avatar picker -------------------------------------------------------
  // Click the profile picture to choose a new one. ImageMagick downscales it
  // to avatarOutSize and the result is cached; then set_config.py repoints
  // displayPicture at it, editing that single key in place so comments and
  // formatting survive. Config.qml watches the file, so the new picture shows
  // up without a restart.
  //
  // ImageMagick is a soft dependency. Without it the picked file is used
  // where it lies, so picking a picture still works, it is just not shrunk.
  readonly property int avatarOutSize: 256
  readonly property string avatarCacheDir: Quickshell.env("HOME") + "/.cache/notch-shell"
  readonly property string avatarCached: avatarCacheDir + "/avatar.png"
  property string avatarSource: ""
  property string avatarStatus: ""
  property bool hasMagick: false

  FileDialog {
    id: avatarDialog
    title: "Choose a profile picture"
    nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)", "All files (*)"]
    onAccepted: {
      shellRoot.avatarSource = selectedFile.toString().replace("file://", "")
      shellRoot.avatarStatus = "processing..."
      if (shellRoot.hasMagick) { resizeProc.running = false; resizeProc.running = true }
      else { setConfigProc.running = false; setConfigProc.running = true }
    }
  }

  // probe once for ImageMagick
  Process {
    id: magickProbe
    command: ["sh", "-c", "command -v magick || command -v convert"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        shellRoot.hasMagick = this.text.trim().length > 0
        magickProbe.running = false
      }
    }
    stderr: StdioCollector { onStreamFinished: magickProbe.running = false }
  }

  // No shell wrapper: the paths are passed as argv, so a file name with a
  // space or a quote in it cannot break the command.
  Process {
    id: resizeProc
    command: ["magick", shellRoot.avatarSource,
              "-auto-orient",
              "-resize", shellRoot.avatarOutSize + "x" + shellRoot.avatarOutSize + "^",
              "-gravity", "center",
              "-extent", shellRoot.avatarOutSize + "x" + shellRoot.avatarOutSize,
              shellRoot.avatarCached]
    running: false
    onExited: exitCode => {
      if (exitCode === 0) { setConfigProc.running = false; setConfigProc.running = true }
      else shellRoot.avatarStatus = "could not resize that image"
    }
  }

  // points the config at whichever copy should be used
  Process {
    id: setConfigProc
    command: ["python3", "/usr/share/notch-shell/scripts/set_config.py",
              "displayPicture", shellRoot.hasMagick ? shellRoot.avatarCached : shellRoot.avatarSource]
    running: false
    onExited: exitCode => {
      shellRoot.avatarStatus = exitCode === 0 ? "profile picture updated" : "could not update the config"
    }
  }

  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48
  property int buttonSize: 20
  property string buttonBg: Theme.bg6
  property string buttonHoverBg: Theme.focusFg1
  property int buttonHoverSpeed: 120
  property int buttonctlRadius: 6

  property bool notifFullscreenMode: false
  property bool fullscreenActive: ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen

  // osd ui
  property int osdInWidth: 120
  property real osdInHeight: 3.7
  property int osdBarRadius: 2
  property int osdSpeed: 60 // how fast bar fill/unfill
  property int osdWidth: 220
  property int osdHeight: 40

  readonly property int notifMaxHeight: 97

  // media player related
  property bool mediaAutoOpened: false
  property var visualizerValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property bool cavaAvailable: false
  property bool nightlightOn: false
  property bool caffeineOn: false

  Process {
    id: cavaCheckProc
    command: ["sh", "-c", "which cava"]
    running: true
    onExited: (exitCode) => { shellRoot.cavaAvailable = (exitCode === 0) }
  }

  PanelWindow {
    id: panelWindow
    WlrLayershell.layer: WlrLayershell.Top
    // controlCenter and miniDashboard joined this list so Escape can reach them;
    // they are the only two overlays that are opened by mouse alone. While one
    // of them is open the surface holds the keyboard, so typing goes to the
    // panel rather than the window behind it.
    WlrLayershell.keyboardFocus: (box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen
                                  || box.powerMenu || box.themePicker
                                  || box.controlCenter || box.miniDashboard
                                  || weatherPopupLoader.item && weatherPopupLoader.item.searchActive)
                                 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitHeight: Math.max(885 * scale, calendarPopup.visible ? calendarPopup.y + calendarPopup.height : 0)
    onScreenChanged: console.log("dpi:", screen.devicePixelRatio)
    property real scale: screen ? screen.devicePixelRatio : 1.0

    anchors {
      top: true
      left: true
      right: true
    }

    // reserve top space only while the pill is shown
    margins.top: box.revealed ? Config.pillTopMargin : 0
    exclusiveZone: box.revealed ? Config.pillBottomMargin : 0
    color: "transparent"

    // Mask input to only the capsule
    mask: Region {
      Region {
        intersection: Intersection.Combine
        x: Math.floor(box.x - box.width * (box.dpi - 1) / 2); y: Math.floor(box.y)
        width: Math.ceil(box.width * box.dpi); height: Math.ceil(box.height * box.dpi)
      }
      // top band to catch the cursor while the pill is hidden in pillOnHover
      Region {
        intersection: Intersection.Combine
        x: 0; y: 0
        width: (Config.pillOnHover && !box.revealed) ? Math.ceil(panelWindow.width) : 0
        height: (Config.pillOnHover && !box.revealed) ? Math.ceil(hoverRevealAreaItem.height) : 0
      }
      Region {
        intersection: Intersection.Combine
        x: Math.floor(calendarPopup.x); y: Math.floor(calendarPopup.y)
        width: calendarPopup.shown ? Math.ceil(calendarPopup.width) : 0
        height: calendarPopup.shown ? Math.ceil(calendarPopup.height) : 0
      }
      Region {
          intersection: Intersection.Combine
          x: Math.floor(themePicker.x); y: Math.floor(themePicker.y)
          width: themePicker.shown ? Math.ceil(themePicker.width) : 0
          height: themePicker.shown ? Math.ceil(themePicker.height) : 0
      }
      Region {
          intersection: Intersection.Combine
          x: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.x) : 0
          y: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.y) : 0
          width: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.width) : 0
          height: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.height) : 0
      }
    }

    // reveal the pill when hovering the top edge in pillOnHover mode.
    // the band leaves the input mask once the pill is shown, so it cannot
    // stay stuck under the pill and block auto-hide
    Item {
      id: hoverRevealAreaItem
      anchors {
        top: parent.top
        topMargin: -Math.round(Config.pillTopMargin)
        left: parent.left
        right: parent.right
      }
      height: Math.max(box.implicitHeight + Config.pillTopMargin + 8, 48)

      HoverHandler {
        id: revealHover
        onHoveredChanged: {
          if (hovered) { shellRoot.pillHoverActive = true; hidePillTimer.stop() }
          else if (!pillHover.hovered) hidePillTimer.start()
        }
      }
    }

    Timer {
      id: hidePillTimer
      interval: 250
      onTriggered: shellRoot.pillHoverActive = false
    }

    // main dynamic pill bar
    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      readonly property bool revealed: !Config.pillOnHover
        || shellRoot.pillHoverActive
        || controlCenter
        || miniDashboard
        || cliphistOpen
        || appLauncher
        || wallpaperSwitcherOpen
        || powerMenu
        || themePicker
        || mediaAutoOpened
        || (notificationModule.active && !notifFullscreenMode)
        || (activeOsd !== "")
      opacity: revealed && (!fullscreenActive && !notifFullscreenMode) ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
      }

      visible: opacity > 0
      clip: true

      property var volumeModule: null
      property var micModule: null
      property var networkModule: null
      property var wifiModule: null
      property var bluetoothModule: null
      property var clockModule: clock
      property var vpnModule: null

      property bool tooltipVisible: false
      property string tooltipModule: ""
      property string customTooltipText: ""
      property real tooltipX: 0
      property real tooltipY: 0

      property bool appLauncher: false
      property bool hovered: false
      property bool miniDashboard: false
      property bool controlCenter: false
      property bool cliphistOpen: false
      property bool wallpaperSwitcherOpen: false
      property bool cliphistPreviewing: false
      property bool powerMenu: false
      property string powerMenuInitialAction: ""
      property bool themePicker: false

      property var battery: UPower.displayDevice
      property bool hasBattery: battery.isLaptopBattery && battery.isPresent
      property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
      readonly property string batteryIconColor: box.charging || box.batteryLevel > 30 ? Theme.okFg : box.batteryLevel <= 15 ? Theme.dangerFg : Theme.warnFg
      readonly property int batteryLevel: hasBattery ? Math.round(battery.percentage * 100) : 0
      // battery icon on laptops, plug icon on desktops
      readonly property string batteryIcon: {
        if (!hasBattery)
          return String.fromCodePoint(0xf06a5) + " " // nf-md-power_plug
        const icons = [0xf0083, 0xf007a, 0xf007d, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0082, 0xf0081, 0xf0079]
        const base = String.fromCodePoint(icons[Math.min(Math.floor(batteryLevel / 10), 9)])
        return charging ? base + String.fromCodePoint(0xf140b) : base
      }

      onChargingChanged: {
        if (!box.controlCenter) box.activeOsd = "battery"
        osdHideTimer.interval = Config.osdDuration
        osdHideTimer.restart()
        console.log("charging:", box.charging, "level:", box.batteryLevel)
      }

      property string accent: Theme.accent

      // control center UI
      property real ccButtonWidth: 85.3
      property int ccButtonHeight: 35
      property int ccButtonRadius: 10
      property string ccButtonBgOff: Theme.bg1
      property string ccButtonFgOff: Theme.fg3
      property int sliderHeight: 4
      property int sliderRadius: 4
      property string sliderColor: Theme.sliderBg
      // invisible extra clickable area above/below the thin slider bars
      // (proportional to the bar height, so it scales with sliderHeight)
      property int sliderHitSlop: sliderHeight * 2
      property int mprisControlsIconSize: 20

      property string activeOsd: "" // volume, brightness, timer, battery

      Process { id: brightnessSetProc; running: false }

      Timer {
        id: osdHideTimer
        onTriggered: box.activeOsd = ""
      }

      onImplicitHeightChanged: {
          // follow launcher live while typing (stacked height animations wobble); animate open/close jumps
          heightAnim.stop()
          if (box.appLauncher && Math.abs(implicitHeight - height) < 120) {
              height = implicitHeight
          } else {
              heightAnim.to = implicitHeight
              heightAnim.duration = mediaAutoOpened ? 650 : 550
              heightAnim.start()
          }
      }

      readonly property int notifBump: notificationModule.notifications.length > 0
        ? (notificationStack ? Math.min(notificationStack.listContentHeight + 40, 130) : 0) : 0

      // adjust pill shape conditionally (pill state)
      readonly property real dpi: Config.dpiScale

      readonly property real baseWidth: activeOsd === "battery" ? osdWidth
                     : activeOsd === "timer" ? osdWidth
                     : activeOsd === "volume" ? osdWidth
                     : activeOsd === "brightness" ? osdWidth
                     : (notificationModule.active && !notifFullscreenMode) ? 320
                     : powerMenu ? 342
                     : controlCenter ? 390
                     : appLauncher ? 378
                     : miniDashboard ? 420
                     : (cliphistOpen && cliphistPreviewing) ? 400
                     : wallpaperSwitcherOpen ? 600
                     : cliphistOpen ? 460
                     : mediaAutoOpened ? 340
                     : row.implicitWidth + (12 * Config.pillScale) + (Config.pillOnHover || !hovered ? 56 : 68) * Config.pillScale

      readonly property real baseHeight: activeOsd === "battery" ? osdHeight
                  : activeOsd === "timer" ? osdHeight
                  : activeOsd === "volume" ? osdHeight
                  : activeOsd === "brightness" ? osdHeight
                  : (notificationModule.active && !notifFullscreenMode) ? 52
                  : powerMenu ? 100
                  : controlCenter && mprisModule.hasPlayer
                      ? (252 + notifBump)
                  : controlCenter
                      ? (152 + notifBump)
                  : (cliphistOpen && cliphistPreviewing) ? 380
                  : miniDashboard ? 155
                  : appLauncher
                      ? (appLauncherLoader.item ? appLauncherLoader.item.height + 23 : 410)
                  : wallpaperSwitcherOpen ? 308
                  : cliphistOpen ? 282
                  : mediaAutoOpened ? 90
                  : (row.implicitHeight * Config.pillScale) + 10

      readonly property real baseRadius: notificationModule.active ? 99
        : cliphistOpen && cliphistPreviewing ? 33
        : cliphistOpen ? 28
        : controlCenter ? (notificationModule.notifications.length > 0
          ? (mprisModule.hasPlayer ? 27 : 25)
          : (mprisModule.hasPlayer ? 26 : 22))
        : appLauncher ? 29
        : miniDashboard ? 20
        : wallpaperSwitcherOpen ? 30
        : mediaAutoOpened ? 22
        : 20 * Config.pillScale

      implicitWidth: baseWidth
      implicitHeight: baseHeight

      // Hanging bar: square against the top edge, rounded at the bottom.
      // Per-corner radii need Qt >= 6.7; the top corners stay sharp.
      radius: 0
      topLeftRadius: 0
      topRightRadius: 0
      bottomLeftRadius: baseRadius
      bottomRightRadius: baseRadius

      scale: dpi
      transformOrigin: Item.Top

      Behavior on bottomLeftRadius {
          NumberAnimation { duration: 225; easing.type: Easing.OutExpo }
      }
      Behavior on bottomRightRadius {
          NumberAnimation { duration: 225; easing.type: Easing.OutExpo }
      }

      color: controlCenter ? Theme.bgD1 : bg

      onMiniDashboardChanged: {
          if (!box.miniDashboard) {
              calendarPopup.shown = false
              if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
          }
      }

      Behavior on implicitWidth { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
      NumberAnimation { id: heightAnim; target: box; property: "height"; easing.type: Easing.OutExpo }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: box.hovered = true
        onExited: box.hovered = false

        onClicked: (mouse) => {

          if (mediaAutoOpened) return

          // clicking the bar closes the theme picker
          if (box.themePicker) {
            box.themePicker = false
            return
          }

          // clicking outside power menu buttons closes it
          if (box.powerMenu) {
            box.powerMenu = false
            box.powerMenuInitialAction = ""
            return
          }

          // restrict control center to only accept left click
          if (box.controlCenter) {
            if (mouse.button === Qt.LeftButton)
                box.controlCenter = false
            return
          }

          // same, cliphist accept middle
          if (box.cliphistOpen) {
            if (mouse.button === Qt.MiddleButton) {
              box.cliphistOpen = false
            }
            return
          }

          // mini dashboard accept only right
          if (box.miniDashboard) {
            if (mouse.button === Qt.RightButton) {
              box.miniDashboard = false
            }
            return
          }

          if (box.wallpaperSwitcherOpen) {
            if (mouse.button !== Qt.LeftButton) {
              return
            }
          }

          if (mouse.button === Qt.LeftButton) {
            console.log("Left click detected, opening control center")
            box.controlCenter = !box.controlCenter
            mediaAutoOpened = false
            box.appLauncher = false
            box.wallpaperSwitcherOpen = false
            box.powerMenu = false
            box.powerMenuInitialAction = ""
            mediaPopupHideTimer.stop()
          }

          if (mouse.button === Qt.MiddleButton) {
            console.log("Middle click detected, opening cliphist")
            mediaAutoOpened = false
            box.appLauncher = false
            box.wallpaperSwitcherOpen = false
            box.powerMenu = false
            box.powerMenuInitialAction = ""
            box.cliphistOpen = !box.cliphistOpen
          }

          if (mouse.button === Qt.RightButton) {
              console.log("Right click detected, opening mini dashboard")
              mediaAutoOpened = false
              box.appLauncher = false
              box.wallpaperSwitcherOpen = false
              box.powerMenu = false
              box.powerMenuInitialAction = ""
              box.miniDashboard = !box.miniDashboard
          }
        }
      }

      // keeps the pill shown while hovered and hides it when the cursor leaves
      HoverHandler {
        id: pillHover
        target: box
        onHoveredChanged: {
          if (hovered) { shellRoot.pillHoverActive = true; hidePillTimer.stop() }
          else if (!revealHover.hovered) hidePillTimer.start()
        }
      }

      Brightness {
          id: brightnessModule
          visible: false
          onBrightnessUpdated: {
              if (!box.controlCenter) box.activeOsd = "brightness"
              osdHideTimer.interval = Config.osdDuration
              osdHideTimer.restart()
          }
      }

      // bar modules and their tooltip
      PillBarModules { id: row }
      TooltipPopup { id: tooltipPopup }

      // volume
      OsdBar {
          active: box.activeOsd === "volume"
          icon: box.volumeModule ? box.volumeModule.icon : ""
          iconColor: box.volumeModule && box.volumeModule.muted ? box.volumeModule.mutedFg : Theme.fg
          percent: box.volumeModule ? Math.min(box.volumeModule.intendedVol / Config.maxVolume, 1.0) : 0
          muted: box.volumeModule ? box.volumeModule.muted : false
          barWidth: box.volumeModule && box.volumeModule.mutedFg ? 80 : 90
          valueText: box.volumeModule ? (box.volumeModule.muted ? "muted" : box.volumeModule.intendedVol + "%") : ""
      }

      // brightness
      OsdBar {
          active: box.activeOsd === "brightness"
          icon: brightnessModule.icon
          percent: brightnessModule.percent
          valueText: Math.round(brightnessModule.percent * 100) + "%"
          barWidth: 100
      }

      // battery
      OsdBar {
        active: box.activeOsd === "battery"
        icon: box.batteryIcon
        iconColor: box.batteryIconColor
        valueText: box.charging ? "Charging" : "Charging stopped"
        barWidth: 0
        spacing: 5 // gap between battery icon and text
      }

      // timer end
      OsdBar {
        active: box.activeOsd === "timer"
        icon: String.fromCodePoint(0xf1ad1)
        iconColor: Theme.infoFg
        valueText: "Timer finished"
        barWidth: 0
        spacing: 5
      }

      // notification
      NotificationPopup {
        active: notificationModule.active
                && !notifFullscreenMode
                && box.activeOsd === ""
        notif: notificationModule.current
      }

      // cliphist opens on middle click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 22
        height: (box.cliphistOpen ? box.implicitHeight - 22 : 0) + cliphistExtraHeight
        opacity: box.cliphistOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter
                 && !box.powerMenu ? 1 : 0
        visible: opacity > 0

        property real cliphistExtraHeight: 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.cliphistOpen ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        Loader {
          id: cliphistLoader
          anchors.fill: parent
          active: box.cliphistOpen
          asynchronous: true

          sourceComponent: Cliphist {
            id: cliphistPanel
            shown: box.cliphistOpen
            onCloseRequested: box.cliphistOpen = false
            onPreviewToggled: (active) => box.cliphistPreviewing = active
          }
        }
      }

      // wallpaper switcher
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 28
        height: box.wallpaperSwitcherOpen ? 280 : 0
        opacity: box.wallpaperSwitcherOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter
                 && !box.miniDashboard
                 && !box.cliphistOpen
                 && !box.appLauncher
                 && !box.powerMenu ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.wallpaperSwitcherOpen ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }
        Loader {
          id: wallpaperLoader
          anchors.fill: parent
          active: box.wallpaperSwitcherOpen
          asynchronous: true
          sourceComponent: WallpaperSwitcher {
            shown: box.wallpaperSwitcherOpen
            onCloseRequested: box.wallpaperSwitcherOpen = false
          }
          onLoaded: item.forceActiveFocus()
        }

        Connections {
          target: box
          function onWallpaperSwitcherOpenChanged() {
            if (box.wallpaperSwitcherOpen && wallpaperLoader.item)
              wallpaperLoader.item.forceActiveFocus()
          }
        }
      }

      // app launcher opens through IPC
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 22
          // height follows launcher (shrinks with results)
          height: box.appLauncher
              ? (appLauncherLoader.item ? appLauncherLoader.item.height : 387)
              : 0
          opacity: box.appLauncher
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.controlCenter
                   && !box.miniDashboard
                   && !box.cliphistOpen
                   && !box.powerMenu ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
              SequentialAnimation {
                  PauseAnimation { duration: box.appLauncher ? 15 : 0 }
                  NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
              }
          }

          Loader {
              id: appLauncherLoader
              width: parent.width
              anchors.horizontalCenter: parent.horizontalCenter
              // keep the launcher alive so its app cache/height persist between opens
              // (avoids the open-time fallback -> empty -> full resize race)
              active: true
              asynchronous: false

              sourceComponent: AppLauncher {
                  shown: box.appLauncher
                  onCloseRequested: box.appLauncher = false
              }
          }
      }

      // power menu
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 25
          height: box.powerMenu ? box.implicitHeight - 18 : 0
          opacity: box.powerMenu
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.controlCenter
                   && !box.miniDashboard
                   && !box.cliphistOpen
                   && !box.appLauncher
                   && !box.wallpaperSwitcherOpen ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
              SequentialAnimation {
                  PauseAnimation { duration: box.powerMenu ? 15 : 0 }
                  NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
              }
          }

          Loader {
              id: powerMenuLoader
              anchors.fill: parent
              active: box.powerMenu
              asynchronous: true

              sourceComponent: PowerMenu {
                  shown: box.powerMenu
                  initialAction: box.powerMenuInitialAction
                  onCloseRequested: {
                      box.powerMenu = false
                      box.powerMenuInitialAction = ""
                  }
              }
              onLoaded: item.forceActiveFocus()
          }

          Connections {
              target: box
              function onPowerMenuChanged() {
                  if (box.powerMenu && powerMenuLoader.item) {
                      powerMenuLoader.item.initialAction = box.powerMenuInitialAction
                      powerMenuLoader.item.forceActiveFocus()
                  } else if (!box.powerMenu) {
                      box.powerMenuInitialAction = ""
                  }
              }
          }
      }

      // media popup
      Item {
          anchors.fill: parent
          opacity: box.activeOsd === ""
                   && !notificationModule.active
                   && !box.controlCenter
                   && !box.cliphistOpen
                   && !box.miniDashboard
                   && !box.appLauncher
                   && !box.wallpaperSwitcherOpen
                   && !box.powerMenu
                   ? 1 : 0
          visible: opacity > 0

          Loader {
              anchors.centerIn: parent
              active: mediaAutoOpened
              asynchronous: true

              sourceComponent: MediaPopup {
                  active: mediaAutoOpened
              }
          }
      }

      // control center opens on left click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 24
        opacity: box.controlCenter && box.activeOsd === "" && !notificationModule.active && !box.powerMenu ? 1 : 0
        visible: opacity > 0
        height: box.controlCenter && box.activeOsd === "" ? box.implicitHeight - 25 : 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.controlCenter ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        // CC contents are only needed while the control centre is open, so
        // load them on demand instead of keeping them resident. Brightness is
        // kept outside this Loader because the OSD reads it directly.
        Loader {
          id: ccLoader
          anchors.fill: parent
          active: box.controlCenter
          asynchronous: false
          sourceComponent: ccContents
        }
      }

      // control centre body, loaded on demand by ccLoader above
      Component {
        id: ccContents
        Item {
          anchors.fill: parent

          // media player
          MediaPlayer {}

          // control center buttons
          CcButtons {
            buttonWidth: box.ccButtonWidth
            buttonHeight: box.ccButtonHeight
            buttonRadius: box.ccButtonRadius
            buttonBgOff: box.ccButtonBgOff
            buttonFgOff: box.ccButtonFgOff
            controlCenterOpen: box.controlCenter
            mediaAutoOpened: mediaAutoOpened
            hasPlayer: mprisModule.hasPlayer
            playerHeight: box.ccButtonHeight
            notificationPopup: notificationModule.active
          }

          CcSliders {
            id: sliderColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: mprisModule.hasPlayer ? box.ccButtonHeight + 121 : 50
            anchors.leftMargin: 15
            anchors.rightMargin: 2

            sliderHeight: box.sliderHeight
            sliderRadius: box.sliderRadius
            sliderColor: box.sliderColor
            sliderHitSlop: box.sliderHitSlop
            volIcon: box.volumeModule.icon
            volMuted: box.volumeModule.muted
            volPercent: box.volumeModule.intendedVol
            volMax: Config.maxVolume
            micIcon: box.micModule ? box.micModule.icon : ""
            micMuted: box.micModule ? box.micModule.muted : false
            micPercent: box.micModule ? box.micModule.intendedVol : 0
            micMax: 100
            brightnessIcon: brightnessModule.icon
            brightnessPercent: brightnessModule.percent

            onVolumeChangeRequested: (fraction) => {
              if (box.volumeModule) {
                box.volumeModule.intendedVol = Math.round(Math.max(0, Math.min(1, fraction)) * Config.maxVolume)
                box.volumeModule.sink.audio.volume = box.volumeModule.intendedVol / 100
              }
            }
            onMicChangeRequested: (fraction) => {
              if (box.micModule && box.micModule.ready) {
                box.micModule.intendedVol = Math.round(Math.max(0, Math.min(1, fraction)) * 100)
                box.micModule.source.audio.volume = box.micModule.intendedVol / 100
              }
            }
            onBrightnessChangeRequested: (fraction) => {
              let pct = Math.round(Math.max(0, Math.min(1, fraction)) * 100)
              brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
              brightnessSetProc.running = false
              brightnessSetProc.running = true
            }
          }

          NotificationStack {
            id: notificationStack
            anchors.top: sliderColumn.bottom
            anchors.topMargin: 32
            anchors.left: parent.left
            anchors.right: parent.right
            notifMaxHeight: 98
            dpi: box.dpi
            controlCenterOpen: box.controlCenter
          }
        }
      }

      // mini dashboard opens on right click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 30
        height: box.miniDashboard ? box.implicitHeight - 30 : 0  // don't fight the animation
        opacity: box.miniDashboard
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.cliphistOpen
                 && !box.powerMenu ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.miniDashboard ? 1 : 0 }
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
          }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    box.miniDashboard = !box.miniDashboard
            }
        }

        RowLayout {
         // profile picture (display picture)
           ClippingRectangle {
            id: avatarClip
            width: avatarSize
            height: avatarSize
            radius: avatarSize / 2
            property string imgPath: Config.displayPicture ? "file://" + Config.displayPicture.replace("~", Quickshell.env("HOME")) : ""
            color: (imgPath === "" || avatarImg.status !== Image.Ready) ? Theme.bg5 : "transparent"
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(avatarSize, avatarSize)

            Image {
              id: avatarImg
              anchors.fill: parent
              source: avatarClip.imgPath
              fillMode: Image.PreserveAspectCrop
              asynchronous: false
              smooth: true
              mipmap: true
              sourceSize: Qt.size(avatarSize, avatarSize)
            }

            // click to choose a different picture
            MouseArea {
              id: avatarMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: avatarDialog.open()
            }

            // ring shown on hover so it reads as clickable
            Rectangle {
              anchors.fill: parent
              radius: avatarSize / 2
              color: "transparent"
              border.width: 2
              border.color: Theme.accent
              opacity: avatarMouse.containsMouse ? 0.9 : 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
            }
          }

          // username
          Process {
            id: whoamiProc
            command: ["sh", "-c", 'whoami']
            running: true
            stdout: StdioCollector {
              onStreamFinished: { whoamiText.text = this.text.trim(); whoamiProc.running = false }
            }
          }

          // hostname
          Process {
            id: hostnameProc
            command: ["sh", "-c", "cat /etc/hostname"]
            running: true
            stdout: StdioCollector {
              onStreamFinished: { hostnameText.text = "(" + this.text.trim() + ")"; hostnameProc.running = false }
            }
          }

          // uptime
          Process {
            id: uptimeProc
            command: ["sh", "-c", 'uptime -p']
            running: true
            stdout: StdioCollector {
              onStreamFinished: uptimeText.text = this.text
            }
          }

          // uptime refresh every 60 sec
          Timer {
            interval: 60000
            running: box.miniDashboard
            repeat: true
            triggeredOnStart: true
            onTriggered: {
              uptimeProc.running = false
              uptimeProc.running = true
            }
          }

          // username + uptime stacked
          ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
              Text {
                id: whoamiText
                color: Theme.fg
                Layout.leftMargin: 10
                font { family: Theme.fontFamily; pixelSize: 14; weight: 600 }
              }

              Text {
                id: hostnameText
                color: Theme.fg5
                Layout.topMargin: 2
                font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
              }
            }

            Text {
              id: uptimeText
              color: Theme.fg4
              Layout.leftMargin: 10
              font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
            }
          }
        }

        // show battery in mini dashboard too
        Battery {
          fontSize: 14
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: 8
          anchors.rightMargin: 12
        }

        // internet protocol information
        IpStatus {
          anchors.left: parent.left
          anchors.leftMargin: 5
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 42
        }

        // cpu usage and temperature, right side. click to expand the
        // per-core list. replaced the data-usage block that sat here
        CpuStats {
          // clear the battery readout that occupies the top right, otherwise
          // the per-core list grows straight up into it
          anchors.right: parent.right
          anchors.rightMargin: 56
          anchors.bottom: parent.bottom
          // the module measures its own room from this, so share the value
          anchors.bottomMargin: bottomInset
        }

        // rectangle where poweroff, sleep etc. buttons placed
        Rectangle {
          color: Theme.bg1
          implicitWidth: 15
          implicitHeight: 30
          radius: 8

          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 97

          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            // nightlight -- warms the screen colour temperature
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius
              color: nightlightOn ? Theme.accent : buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "\uf186";
                color: nightlightOn ? Theme.onAccent : (nightlightHover.containsMouse ? buttonHoverBg : Theme.fg);
                font.pixelSize: 9
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: nightlightHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: nightlightOn = !nightlightOn
                hoverEnabled: true
              }

              Process {
                id: nightlightProc
                command: ["wlsunset", "-t", String(Config.nightlightTemperature), "-T", "6500"]
                running: nightlightOn
              }
            }

            // caffeine -- inhibits idle/sleep while on
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius
              color: caffeineOn ? Theme.accent : buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "\uf0f4";
                color: caffeineOn ? Theme.onAccent : (caffeineHover.containsMouse ? buttonHoverBg : Theme.fg);
                font.pixelSize: 9
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: caffeineHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: caffeineOn = !caffeineOn
                hoverEnabled: true
              }

              Process {
                id: caffeineProc
                command: ["systemd-inhibit", "--what=idle:sleep", "--who=notch-shell", "--why=Caffeine", "--mode=block", "sleep", "infinity"]
                running: caffeineOn
              }
            }

            Item { Layout.fillWidth: true }

            Datetime { id: datetimeItem; dateFg: Theme.fg4; }

            Item { Layout.fillWidth: true }

            Weather { id: weatherIndicatorItem; fg: Theme.fg4; clickable: true }

            Item { Layout.fillWidth: true }

            // reboot
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "";
                color: rebootHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 9;
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: rebootHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (Config.confirmPowerActions) {
                    box.powerMenuInitialAction = "reboot"
                    box.miniDashboard = false
                    box.powerMenu = true
                  } else {
                    rebootProc.running = false
                    rebootProc.running = true
                  }
                }
                hoverEnabled: true
              }
              Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
            }

            // shutdown
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "󰐥";
                color: shutdownHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 12;
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: shutdownHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (Config.confirmPowerActions) {
                    box.powerMenuInitialAction = "shutdown"
                    box.miniDashboard = false
                    box.powerMenu = true
                  } else {
                    shutdownProc.running = false
                    shutdownProc.running = true
                  }
                }
                hoverEnabled: true
              }
              Process { id: shutdownProc; command: ["bash", "-c", "systemctl poweroff"]; running: false }
            }
          }
        }
      }
      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }

    // theme picker popup
    ThemePicker {
      id: themePicker
      shown: box.themePicker
    }

    // calendar popup box
    CalendarBox { id: calendarPopup }

    Loader {
        id: weatherPopupLoader
        active: false
        asynchronous: false

        sourceComponent: WeatherPopup {
            onShownChanged: if (!shown) closeTimer.start()
        }

        onLoaded: item.shown = true
        Timer {
            id: closeTimer
            interval: 250
            onTriggered: weatherPopupLoader.active = false
        }
    }

    // open calendar when click on date in mini dashboard
    Connections {
      target: datetimeItem
      function onToggleCalendar() {
        console.log("toggleCalendar launched, current opacity:", calendarPopup.opacity)
        calendarPopup.shown = !calendarPopup.shown
        if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
      }
    }

    // open weather when click on weather in mini dashboard
    Connections {
      target: weatherIndicatorItem
      function onToggleWeather() {
        if (mediaAutoOpened) return
        if (!weatherPopupLoader.active)
          weatherPopupLoader.active = true
        else
          weatherPopupLoader.item.shown = !weatherPopupLoader.item.shown
        calendarPopup.shown = false
      }
    }

    Connections {
        target: mprisModule
        function onNowPlaying() {
            if (box.controlCenter) return
            if (!box.mediaPopup) mediaAutoOpened = true
            mediaPopupHideTimer.restart()
        }
    }

    Timer {
        id: mediaPopupHideTimer
        interval: Config.mediaPopupDuration
        repeat: false
        onTriggered: {
          if (mediaAutoOpened) mediaAutoOpened = false
        }
    }

    Connections {
      target: countdownModule
      function onTimerFinished() {
        if (!box.controlCenter) box.activeOsd = "timer"
        osdHideTimer.interval = 2500
        osdHideTimer.restart()
      }
    }
  }

  // Bottom-left notch: every open window, taskbar style. Dismissed whenever
  // an overlay in the main bar takes over, so the two never fight for input.
  AppsNotch {
    id: appsNotch
    Connections {
      target: box
      function onControlCenterChanged() { if (box.controlCenter) { appsNotch.closeMenu(); appsNotch.shown = false } }
      function onMiniDashboardChanged() { if (box.miniDashboard) { appsNotch.closeMenu(); appsNotch.shown = false } }
      function onAppLauncherChanged() { if (box.appLauncher) { appsNotch.closeMenu(); appsNotch.shown = false } }
      function onPowerMenuChanged() { if (box.powerMenu) { appsNotch.closeMenu(); appsNotch.shown = false } }
      function onThemePickerChanged() { if (box.themePicker) { appsNotch.closeMenu(); appsNotch.shown = false } }
    }
  }

  // Bottom-right notch: system tray icons.
  TrayNotch {
    id: trayNotch
    Connections {
      target: box
      function onControlCenterChanged() { if (box.controlCenter) { trayNotch.closeMenu(); trayNotch.shown = false } }
      function onMiniDashboardChanged() { if (box.miniDashboard) { trayNotch.closeMenu(); trayNotch.shown = false } }
      function onAppLauncherChanged() { if (box.appLauncher) { trayNotch.closeMenu(); trayNotch.shown = false } }
      function onPowerMenuChanged() { if (box.powerMenu) { trayNotch.closeMenu(); trayNotch.shown = false } }
      function onThemePickerChanged() { if (box.themePicker) { trayNotch.closeMenu(); trayNotch.shown = false } }
    }
  }

  MprisModule { id: mprisModule; visible: false }

  CountdownModule { id: countdownModule; visible: false }

  NotificationServer {
    id: notifServer
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    persistenceSupported: true
    onNotification: notif => {
      notif.tracked = true
      notificationModule.enqueue(notif)
    }
  }

  NotificationModule { id: notificationModule; visible: false }

  FullscreenOsd {
    id: fsNotif
    active: notificationModule.active && notifFullscreenMode
    visible: notifFullscreenMode
    cardWidth: 300 * box.dpi
    cardHeight: 52 * box.dpi

    property var displayNotif: null

    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: 12 * box.dpi

      Text {
        text: String.fromCodePoint(0xf0f3)
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 14 * box.dpi }
        visible: cardIcon.status !== Image.Ready
      }

      Image {
        id: cardIcon
        width: 23; height: 23
        fillMode: Image.PreserveAspectCrop
        source: {
          if (fsNotif.displayNotif && fsNotif.displayNotif.image) return fsNotif.displayNotif.image
          if (fsNotif.displayNotif && fsNotif.displayNotif.appIcon) {
            return fsNotif.displayNotif.appIcon.startsWith("/")
              ? "file://" + fsNotif.displayNotif.appIcon
              : "image://icon/" + fsNotif.displayNotif.appIcon
          }
          return ""
        }
        sourceSize: Qt.size(23 * box.dpi, 23 * box.dpi)
        visible: status === Image.Ready
      }

      ColumnLayout {
        spacing: 3 * box.dpi

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.summary : ""
          textFormat: Text.PlainText
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 10 * box.dpi; weight: 700 }
          elide: Text.ElideRight
          Layout.maximumWidth: 200
        }

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.body.replace(
            /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
            '<a href="$2">$1</a>'
          ) : ""
          textFormat: Text.StyledText
          linkColor: Theme.accent
          color: Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 9 * box.dpi }
          elide: Text.ElideRight
          visible: text !== ""
          Layout.maximumWidth: 200
        }
      }
    }
  }

  Connections {
    target: notificationModule
    function onActiveChanged() {
        if (notificationModule.active) {
            notifFullscreenMode = fullscreenActive
        } else {
            notifFullscreenMode = false
        }
    }
    function onCurrentChanged() {
      if (notificationModule.current) fsNotif.displayNotif = notificationModule.current
    }
  }

  // audio visualizer spectrum process
  Process {
    id: cavaProc
    command: ["sh", "-c", "cava -p ~/.cache/notch-shell/cava.conf"]
    running: Config.showAudioVisuals && box.controlCenter && shellRoot.cavaAvailable
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        let parts = data.trim().split(";")
        let vals = []
        for (let i = 0; i < 16; i++) {
          let v = Number(parts[i])
          vals.push(isNaN(v) ? 0 : Math.min(100, Math.max(0, v)))
        }
        shellRoot.visualizerValues = vals
      }
    }
  }

}


