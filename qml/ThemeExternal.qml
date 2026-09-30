pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Reads the palette that wallust generates from the current wallpaper.
//
// wallust owns palette generation entirely; this file only maps its output onto
// the same anchor set every built-in theme uses, so ThemeRamp expands it
// exactly like a hand-written palette. That mapping is the shell's job rather
// than wallust's, because "accent" and "raised" only mean something to the UI
// that draws them.
//
// The file is written by wallust, so it is read as raw text and parsed rather
// than through a JsonAdapter: wallust rewrites it on every wallpaper change and
// a read that lands mid-write would make a schema binding throw. Parsing is
// guarded and the last good palette is kept, so a truncated write shows the
// previous theme for a frame instead of blanking the bar.
Singleton {
    id: root

    // where install.sh points wallust's template output
    readonly property string themePath: Quickshell.env("HOME") + "/.config/notch-shell/theme-wallust.json"

    property var data: null
    property string parseError: ""

    readonly property bool available: data !== null
        && typeof data.background === "string"
        && typeof data.foreground === "string"
        && Array.isArray(data.colors)
        && data.colors.length >= 8

    // the wallpaper wallust last sampled, used to notice an out-of-band change
    readonly property string sampledWallpaper: available ? String(data.wallpaper || "") : ""

    readonly property string source: available
        ? "wallust " + String(data.colorspace || "") + "/" + String(data.palette || "")
        : (parseError ? "unreadable" : "none")

    // wallust rewrites this file on every wallpaper change.
    //
    // onLoaded is the hook that fires once the bytes are actually readable;
    // onFileChanged alone only reports that the path changed, and reading
    // there races the write and settles on the previous palette.
    FileView {
        id: file
        path: root.themePath
        watchChanges: true
        blockLoading: false
        // the file legitimately does not exist until wallust first runs, so a
        // missing file is expected rather than worth logging
        printErrors: false
        onLoaded: root.ingest()
        onFileChanged: file.reload()
    }

    // Parsed imperatively rather than bound, so a bad read leaves the last good
    // palette in place instead of throwing out of a binding and taking the
    // whole theme with it.
    function ingest() {
        // file.text() is a call, not a property read: under quickshell 0.3.1
        // `file.text` evaluates to the function object, which stringifies to
        // "function text() { [native code] }" and parses as nothing.
        const raw = file.text()
        if (!raw || raw.length === 0) return
        let parsed = null
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            // truncated or half-written; keep the palette we already had
            root.parseError = "malformed"
            return
        }
        if (parsed === null || typeof parsed !== "object") {
            root.parseError = "not an object"
            return
        }
        root.parseError = ""
        root.data = parsed
    }

    // --- mapping ------------------------------------------------------------

    // wallust's palette name says light or dark outright; fall back to the
    // background's own luminance when the name is missing or unfamiliar.
    readonly property bool isLight: {
        if (!available) return false
        const p = String(data.palette || "").toLowerCase()
        if (p.indexOf("light") !== -1) return true
        if (p.indexOf("dark") !== -1) return false
        return ThemeRamp.relLum(data.background) > 0.32
    }

    // Most colourful of the 16, ranked on absolute channel spread rather than
    // the (max-min)/max saturation ratio. The ratio rates near-black highly,
    // because a colour with a zero channel looks saturated however dark it is.
    readonly property string accentColor: {
        if (!available) return "#6c8cff"
        let best = data.colors[0], bestSpread = -1
        for (const c of data.colors) {
            const x = ThemeRamp.parse(c)
            const spread = Math.max(x.r, x.g, x.b) - Math.min(x.r, x.g, x.b)
            if (spread > bestSpread) { bestSpread = spread; best = c }
        }
        return best
    }

    // Walks `c` away from `base` until it clears `floor`, synthesising a colour
    // when the source is too flat to get there on its own.
    function readable(base, c, dir, floor) {
        if (ThemeRamp.contrast(c, base) >= floor) return c
        let col = ThemeRamp.shade(c, 0)
        for (let i = 0; i < 24; i++) {
            col = ThemeRamp.shade(col, dir * 0.08)
            if (ThemeRamp.contrast(col, base) >= floor) break
        }
        return col
    }

    readonly property var palette: {
        if (!available) return null
        const dark = !isLight
        const bg = data.background

        // wallust's foreground is tuned to be a legible terminal colour, which
        // on a saturated wallpaper is a fully saturated hue. Using it verbatim
        // tints every label, so it is pulled most of the way to white (black on
        // a light theme) and only then checked for contrast. What survives is a
        // faint cast of the wallpaper instead of a colour wash.
        const fg = ThemeRamp.mix(data.foreground, dark ? "#ffffff" : "#000000", 0.72)
        const text = readable(bg, fg, dark ? 1 : -1, 4.5)

        // surfaces step away from the background, extrapolating past the
        // palette's own range so a flat wallpaper still gets a usable ramp
        const raised = ThemeRamp.shade(bg, dark ? 0.05 : -0.05)
        const high = ThemeRamp.shade(bg, dark ? 0.10 : -0.10)
        const muted = ThemeRamp.mix(text, bg, 0.34)
        const faint = ThemeRamp.mix(text, bg, 0.62)

        let accent = accentColor
        if (ThemeRamp.contrast(accent, bg) < 3.0) {
            const towards = dark ? "#ffffff" : "#000000"
            const alt = ThemeRamp.mix(accent, towards, 0.35)
            accent = ThemeRamp.contrast(alt, bg) >= 3.0 ? alt : ThemeRamp.polar(accent, 0.25, bg)
        }

        return {
            base: bg,
            raised: raised,
            high: high,
            text: text,
            muted: muted,
            faint: faint,
            accent: accent,
            glow: accent,
            // status colours are never sampled from the wallpaper: "danger" has
            // to stay red whatever the image is, or the row becomes invisible
            warning: "#fac94a",
            danger: "#e32626",
            ok: "#4bd25c",
            info: "#6791dc"
        }
    }

    // Same entry shape ThemePalettes.get() returns, so Theme.qml treats this
    // exactly like a built-in theme.
    readonly property var entry: palette ? {
        label: "Wallpaper",
        light: isLight,
        swatches: available
            ? [data.background, data.colors[Math.floor(data.colors.length / 2)], data.foreground, accentColor]
            : [],
        palette: palette,
        literal: undefined
    } : null
}
