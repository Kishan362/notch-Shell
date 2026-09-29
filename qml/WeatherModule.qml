pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: root

  property real temp: 0
  property real feelsLike: 0
  property int humidity: 0
  property real windSpeed: 0
  property string windDir: ""
  property int uvIndex: 0
  property string condition: ""
  property string weatherCode: ""
  property string iconGlyph: "\ue312"  // weather-cloudy
  property string iconColor: Theme.fg4
  property string sunrise: ""
  property string sunset: ""
  property var forecast: []
  property bool loading: false
  property string errorMessage: ""
  property var lastUpdated: new Date()
  property bool hasData: false
  property bool isStale: false
  property bool isError: errorMessage.length > 0 && !isStale

  function iconForCode(code) {
    const c = parseInt(code)
    if (c === 113) return { glyph: "\ue30d", color: "#f4c542" }   // sunny day. yellow
    if ([116, 119, 122].includes(c)) return { glyph: "\ue312", color: "#9aa0a6" }  // cloudy, grey
    if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 353, 356, 359].includes(c))
      return { glyph: "\ue318", color: "#4a9de8" }  // rain, blue
    if ([200, 386, 389, 392, 395].includes(c)) return { glyph: "\ue31d", color: "#e8b84a" }  // thunderstorm, amber
    if ([227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].includes(c))
      return { glyph: "\ue31a", color: Theme.weatherSnow }  // snow, near-white
    if ([143, 248, 260].includes(c)) return { glyph: "\ue313", color: "#8a8a8a" }  // fog, dim grey
    return { glyph: "\ue312", color: "#9aa0a6" }
  }

  // what we actually ask the API for: precise coords when the picker set them,
  // otherwise the plain city string (upstream behaviour)
  readonly property string query: Config.weatherQuery && Config.weatherQuery.trim() !== ""
                             ? Config.weatherQuery : Config.weatherLocation
  // what the UI shows: always the human-readable place name
  readonly property string locationLabel: Config.weatherLocation

  // ---- location search / detect, used by the weather popup ----
  property bool geoSearching: false
  property var geoResults: []
  property string geoError: ""

  function geoSearch(text) {
    const q = String(text || "").trim()
    if (q.length < 2) { root.geoResults = []; root.geoSearching = false; return }
    root.geoSearching = true
    root.geoError = ""
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      root.geoSearching = false
      if (xhr.status !== 200) {
        root.geoResults = []
        root.geoError = "Search failed"
        return
      }
      try {
        const data = JSON.parse(xhr.responseText)
        root.geoResults = (data.results || []).slice(0, 6).map(r => ({
          name: r.name,
          admin: r.admin1 || "",
          country: r.country || "",
          lat: r.latitude,
          lon: r.longitude
        }))
        if (root.geoResults.length === 0) root.geoError = "No match"
      } catch (e) { root.geoError = "Search failed" }
    }
    xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&name="
                   + encodeURIComponent(q))
    xhr.send()
  }

  function clearGeo() {
    root.geoResults = []
    root.geoError = ""
    root.geoSearching = false
  }

  // IP geolocation. Which city you get depends on how your ISP routes you, so
  // this is a starting point rather than gospel - hence the search box too.
  function detectLocation() {
    root.geoSearching = true
    root.geoError = ""
    const finish = (d) => {
      root.geoSearching = false
      const city = d.city || d.region || ""
      if (!city) { root.geoError = "Detect failed"; return }
      const lat = d.latitude !== undefined ? d.latitude : d.lat
      const lon = d.longitude !== undefined ? d.longitude : d.lon
      root.geoResults = [{
        name: city,
        admin: d.region || d.regionName || "",
        country: d.country_name || d.country || "",
        lat: parseFloat(lat),
        lon: parseFloat(lon)
      }]
    }
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status === 200) {
        try {
          const d = JSON.parse(xhr.responseText)
          if (d.success === false) { root.geoSearching = false; root.geoError = "Detect failed"; return }
          finish(d)
        } catch (e) { root.geoSearching = false; root.geoError = "Detect failed" }
      } else {
        // ipwho.is can rate-limit; geojs is a decent second try
        const x2 = new XMLHttpRequest()
        x2.onreadystatechange = () => {
          if (x2.readyState !== XMLHttpRequest.DONE) return
          root.geoSearching = false
          if (x2.status !== 200) { root.geoError = "Detect failed"; return }
          try { finish(JSON.parse(x2.responseText)) } catch (e) { root.geoError = "Detect failed" }
        }
        x2.open("GET", "https://get.geojs.io/v1/ip/geo.json")
        x2.send()
      }
    }
    xhr.open("GET", "https://ipwho.is/")
    xhr.send()
  }

  function refresh() {
    root.loading = true
    const url = "https://wttr.in/" + encodeURIComponent(root.query) + "?format=j1"
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      root.loading = false
      if (xhr.status !== 200) {
        root.errorMessage = "Weather fetch failed."
        root.isStale = root.hasData
        return
      }
      try {
        const data = JSON.parse(xhr.responseText)
        const current = data.current_condition[0]
        const today = data.weather[0]
        const isMetric = Config.weatherUnits === "metric"

        root.temp = isMetric ? parseFloat(current.temp_C) : parseFloat(current.temp_F)
        root.feelsLike = isMetric ? parseFloat(current.FeelsLikeC) : parseFloat(current.FeelsLikeF)
        root.humidity = parseInt(current.humidity)
        root.windSpeed = isMetric ? parseFloat(current.windspeedKmph) : parseFloat(current.windspeedMiles)
        root.windDir = current.winddir16Point
        root.uvIndex = parseInt(current.uvIndex)
        root.condition = current.weatherDesc[0].value
        root.weatherCode = current.weatherCode

        const iconData = root.iconForCode(current.weatherCode)
        root.iconGlyph = iconData.glyph
        root.iconColor = iconData.color

        root.sunrise = today.astronomy[0].sunrise
        root.sunset = today.astronomy[0].sunset

        root.forecast = data.weather.slice(0, 3).map(day => {
          const dayIcon = root.iconForCode(day.hourly[4].weatherCode)
          return {
            date: day.date,
            maxTemp: isMetric ? parseFloat(day.maxtempC) : parseFloat(day.maxtempF),
            minTemp: isMetric ? parseFloat(day.mintempC) : parseFloat(day.mintempF),
            iconGlyph: dayIcon.glyph,
            iconColor: dayIcon.color
          }
        })

        root.lastUpdated = new Date()
        root.hasData = true
        root.isStale = false
        root.errorMessage = ""
      } catch (e) {
        root.errorMessage = "Weather parse failed"
        root.isStale = root.hasData
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  Timer {
    interval: Config.weatherRefreshInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
