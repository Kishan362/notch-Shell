pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  FileView {
    path: Quickshell.env("HOME") + "/.config/notch-shell/config.jsonc"
    watchChanges: true
    onFileChanged: reload()

    // fallback values
    JsonAdapter {
      id: adapter
      // Empty, not "$HOME/.pfp.png": the avatar Image binds this before the
      // user config has finished loading, and a source pointing at a file that
      // is not there logs "Cannot open" on every shell start. An empty source
      // loads nothing, and the real displayPicture from config.jsonc replaces
      // it as soon as the adapter is populated.
      property string displayPicture: ""
      property string clockFormat: "hh:mm"
      // 0, not upstream's 9: the layer-shell surface is first committed with
      // this pre-load fallback, and wlr-layer-shell never re-applies a margin
      // change to 0 afterwards, so a 9 here leaves the bar stranded 9px down
      // on every cold start. A non-zero config value still works (it commits
      // at 0, then updates).
      property int pillTopMargin: 0
      property int pillBottomMargin: 26
      property string textFontFamily: "Monocraft"
      property string nerdFontFamily: "JetBrainsMono Nerd Font Propo"
      property list<int> timerPresets: [1, 5, 10, 15, 30]
      property int mediaPopupDuration: 3000
      property int maxWorkspaces: 5
      property int notificationDisplayTime: 3000
      property int maxNotificationsInStack: 20
      property int dataUsageRefreshInterval: 300000
      property string screenLockAppCommand: "hyprlock"
      property int osdDuration: 800
      property string weatherUnits: "metric"
      property string weatherLocation: "Delhi"
      // optional precise "lat,lon"; when empty the weather module falls back to
      // weatherLocation. Set by the location picker in the weather popup.
      property string weatherQuery: ""
      property int weatherRefreshInterval: 3600000
      property int nightlightTemperature: 4000
      property bool avoidDuplicateNotifications: true
      property string defaultTerminal: "kitty"
      property real pillScale: 1.0
      property real dpiScale: 1.0
      // the wallpaper that is actually applied, written by the wallpaper
      // switcher. the "wallpaper" theme samples this.
      property string currentWallpaper: ""
      property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
      property bool wsCloseOnWallpaperSet: true
      property bool wsAnimation: true
      property bool deleteCliphistImgCache: true
      // "none", not upstream's "Japan": the holidays FileView path is a live
      // binding, so before the config file loads the fallback would send it
      // off to read a Japanese cache that does not exist. Both Clock.qml and
      // CalendarBox.qml treat "none" as disabled.
      property string country: "none"
      property bool showAudioVisuals: true
      property bool showSensitiveInfo: true
      property var pillModules: ["battery", "volume", "mic", "workspaces", "network", "clock"]
      property string customWallpaperScript: ""
      property bool pillOnHover: false
      property bool confirmPowerActions: true
      property int maxVolume: 100
      property bool separatePreviewTabTypes: true
      property string theme: "nord"
    }
  }

  readonly property alias displayPicture: adapter.displayPicture
  readonly property alias clockFormat: adapter.clockFormat
  readonly property alias pillTopMargin: adapter.pillTopMargin
  readonly property alias pillBottomMargin: adapter.pillBottomMargin
  readonly property alias textFontFamily: adapter.textFontFamily
  readonly property alias nerdFontFamily: adapter.nerdFontFamily
  readonly property alias timerPresets: adapter.timerPresets
  readonly property alias mediaPopupDuration: adapter.mediaPopupDuration
  readonly property alias maxWorkspaces: adapter.maxWorkspaces
  readonly property alias notificationDisplayTime: adapter.notificationDisplayTime
  readonly property alias maxNotificationsInStack: adapter.maxNotificationsInStack
  readonly property alias dataUsageRefreshInterval: adapter.dataUsageRefreshInterval
  readonly property alias screenLockAppCommand: adapter.screenLockAppCommand
  readonly property alias osdDuration: adapter.osdDuration
  readonly property alias weatherUnits: adapter.weatherUnits
  readonly property alias weatherLocation: adapter.weatherLocation
  readonly property alias weatherQuery: adapter.weatherQuery
  readonly property alias weatherRefreshInterval: adapter.weatherRefreshInterval
  readonly property alias avoidDuplicateNotifications: adapter.avoidDuplicateNotifications
  readonly property alias defaultTerminal: adapter.defaultTerminal
  readonly property alias pillScale: adapter.pillScale
  readonly property alias dpiScale: adapter.dpiScale
  readonly property alias currentWallpaper: adapter.currentWallpaper
  readonly property alias wallpapersDir: adapter.wallpapersDir
  readonly property alias wsCloseOnWallpaperSet: adapter.wsCloseOnWallpaperSet
  readonly property alias wsAnimation: adapter.wsAnimation
  readonly property alias deleteCliphistImgCache: adapter.deleteCliphistImgCache
  readonly property alias country: adapter.country
  readonly property alias showAudioVisuals: adapter.showAudioVisuals
  readonly property alias showSensitiveInfo: adapter.showSensitiveInfo
  readonly property alias pillModules: adapter.pillModules
  readonly property alias customWallpaperScript: adapter.customWallpaperScript
  readonly property alias pillOnHover: adapter.pillOnHover
  readonly property alias confirmPowerActions: adapter.confirmPowerActions
  readonly property alias maxVolume: adapter.maxVolume
  readonly property alias separatePreviewTabTypes: adapter.separatePreviewTabTypes
  readonly property alias theme: adapter.theme
}
