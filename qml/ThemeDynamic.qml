pragma Singleton
import Quickshell
import QtQuick

// Builds a palette from the current wallpaper.
//
// The wallpaper is sampled with ImageMagick, which returns a handful of
// dominant colours already clustered by similarity. Those are sorted by
// luminance and mapped onto the same anchor set every built-in theme uses, so
// ThemeRamp expands them exactly like any hand-written palette and no other
// file has to know this exists.
//
// Two rules keep the result readable no matter what the wallpaper looks like:
//
//   - status colours are never taken from the image. A red wallpaper would
//     otherwise paint "danger" red and make the row invisible.
//   - text and background are pushed apart until they clear the contrast floor,
//     because plenty of wallpapers are a single flat mid-tone with no range at
//     all, and a faithful copy of that would be unreadable.
Singleton {
    id: root

    // "wallpaper" is reserved in Config.theme and means "use this".
    readonly property string themeName: "wallpaper"

    // mirrored from Config so this singleton can watch it and re-sample
    readonly property string currentWallpaper: Config.currentWallpaper

    // hex list from the sampler, most frequent first
    property var sampled: []
    property bool sampling: false
    property string samplerError: ""

    // set when no wallpaper is known yet, so Theme.qml can fall back
    readonly property bool available: sampled.length >= 2

    readonly property bool isLight: {
        if (!available) return false
        // the average of the extremes tracks the overall tone better than any
        // single swatch, which may be a bright accent on a dark image
        const lo = ThemeRamp.relLum(sampled[0])
        const hi = ThemeRamp.relLum(sampled[sampled.length - 1])
        return (lo + hi) / 2 > 0.32
    }

    // The sampler lives in shell.qml, not here: a Process parented to a
    // `pragma Singleton` never runs under quickshell 0.3.1, so the shell owns
    // the process and pushes the result in through these calls.
    function beginSample() {
        if (!root.currentWallpaper) {
            root.sampled = []
            root.sampling = false
            return false
        }
        root.sampling = true
        root.samplerError = ""
        return true
    }

    function finishSample(hexes) {
        root.sampled = hexes
        root.sampling = false
        root.samplerError = hexes.length ? "" : "could not read that image"
    }

    function failSample(why) {
        root.sampled = []
        root.sampling = false
        root.samplerError = why
    }

  // --- colour helpers, built on ThemeRamp so the maths is identical ---

    function byLuma(a, b) { return ThemeRamp.luma(a) - ThemeRamp.luma(b) }

    // Sorts the sample dark -> light and drops near-duplicates, which magick
    // emits when an image has a smooth gradient.
    readonly property var ordered: {
        const s = sampled.slice().sort(root.byLuma)
        const out = []
        for (const c of s) {
            if (out.length === 0 || ThemeRamp.contrast(c, out[out.length - 1]) > 1.12) out.push(c)
        }
        return out
    }

    // Most colourful swatch, used for the accent.
    //
    // Ranked on the absolute channel spread (max - min) rather than the usual
    // (max - min) / max saturation ratio. The ratio scores near-black highly,
    // because a colour with min 0 always looks saturated however dark it is, so
    // a red wallpaper picked #070001 as its "accent" and the contrast fix then
    // washed it out to grey. Spread only counts colour that is actually there.
    readonly property string accentColor: {
        if (ordered.length === 0) return "#6c8cff"
        let best = ordered[0], bestScore = -1
        for (const c of ordered) {
            const x = ThemeRamp.parse(c)
            const spread = Math.max(x.r, x.g, x.b) - Math.min(x.r, x.g, x.b)
            if (spread > bestScore) { bestScore = spread; best = c }
        }
        return best
    }

    // Picks whichever end of the ramp reads best on `base`, then walks it away
    // from base until the contrast floor is met. Returns null if the base is so
    // mid-tone that neither end can get there, so the caller can fall back.
    function readable(base, candidates, dir, floor) {
        let c = candidates
        for (let i = 0; i < c.length; i++) {
            if (ThemeRamp.contrast(c[i], base) >= floor) return c[i]
        }
        // nothing in the sample reaches the floor: synthesise one by shading
        // the extreme toward white or black until it does
        let t = ThemeRamp.luma(base) > 0.4 ? 1 : -1
        let col = ThemeRamp.shade(c[c.length - 1], 0)
        for (let i = 0; i < 20; i++) {
            col = ThemeRamp.shade(col, t * 0.1)
            if (ThemeRamp.contrast(col, base) >= floor) break
        }
        return col
    }

    // --- the palette, in the same shape ThemePalettes uses ---

    readonly property var palette: {
        if (ordered.length < 2) return null
        const o = ordered
        const dark = !isLight

        // background end: darkest for a dark theme, lightest for a light one
        const bg = dark ? o[0] : o[o.length - 1]
        // the next two swatches in, stepped away from bg, give the raised/high
        // anchors; extrapolating past the ends of the sample keeps a flat
        // wallpaper from collapsing the whole surface ramp to one colour
        const step = (i) => {
            const idx = dark ? i : o.length - 1 - i
            if (idx >= 0 && idx < o.length) return o[idx]
            return ThemeRamp.shade(bg, dark ? i * 0.06 : -(i * 0.06))
        }

        const raised = step(1)
        const high = step(2)

        // Foreground end. The wallpaper's own extreme is only a starting point:
        // using a vivid swatch verbatim tints every label in the UI, so it is
        // pulled most of the way to white (or black on a light theme) and then
        // pushed away from bg until it clears the contrast floor. What survives
        // is a faint cast of the wallpaper rather than a colour wash.
        const fg = dark ? o[o.length - 1] : o[0]
        const softened = ThemeRamp.mix(fg, dark ? "#ffffff" : "#000000", 0.72)
        const text = root.readable(bg, [softened, fg], dark ? 1 : -1, 4.5)
        const muted = ThemeRamp.mix(text, bg, 0.34)
        const faint = ThemeRamp.mix(text, bg, 0.62)

        // accent has to read against the bar surface too
        let accent = root.accentColor
        if (ThemeRamp.contrast(accent, bg) < 3.0) {
            const towards = dark ? 1 : -1
            const alt = ThemeRamp.mix(accent, towards > 0 ? "#ffffff" : "#000000", 0.35)
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
            // status colours are deliberately not sampled: "danger" has to stay
            // red whatever the wallpaper is
            warning: "#fac94a",
            danger: "#e32626",
            glow: accent,
            ok: "#4bd25c",
            info: "#6791dc"
        }
    }

    // Same entry shape ThemePalettes.get() returns, so Theme.qml can treat
    // this exactly like a built-in theme.
    readonly property var builtinEntry: available && palette ? {
        label: "Wallpaper",
        light: isLight,
        swatches: [ordered[0], ordered[Math.floor(ordered.length / 2)], ordered[ordered.length - 1], accentColor],
        palette: palette,
        literal: undefined
    } : null

    // Resolution order for the "wallpaper" theme:
    //
    //   1. the palette wallust generated - preferred, because wallust does the
    //      colour science properly rather than approximating it here
    //   2. this file's own ImageMagick sampler - keeps the theme working when
    //      wallust is not installed, so removing it never leaves the bar grey
    //   3. null, and Theme.qml falls back to the default palette
    //
    // The source is exposed so the picker can say which one is live. A silent
    // fallback is exactly the failure mode that makes dynamic theming look
    // broken: the wallpaper changes and nothing acknowledges it.
    readonly property var entry: ThemeExternal.available ? ThemeExternal.entry : builtinEntry

    readonly property string source: ThemeExternal.available
        ? ThemeExternal.source
        : (available ? "built-in sampler" : "unavailable")

    readonly property string sourceWallpaper: ThemeExternal.available
        ? ThemeExternal.sampledWallpaper
        : root.currentWallpaper
}
