pragma Singleton
import Quickshell
import QtQuick

// Derives the full Theme property set from a handful of anchor colors.
//
// Each theme only declares ~10 anchors (base, raised, high, text, muted, faint,
// accent, warning, danger, glow). The long bg / fg / border / focus ramps are
// interpolated here so every theme stays monotonic and internally consistent
// instead of relying on 44 hand-picked hex values per palette.
//
// Colors are blended in plain JS rather than via Qt.lighter()/Qt.darker() so the
// result is exact and reproducible, and so an interpolated ramp is monotonic by
// construction as long as the anchors are ordered dark -> light.
//
// A theme may also carry a `literal` object; those values override the derived
// ones. ThemeDefault uses this to reproduce the stock greys byte for byte.
Singleton {
    id: root

    readonly property color black: "#000000"
    readonly property color white: "#ffffff"

    function parse(c) {
        let s = String(c).trim()
        if (s[0] !== "#")
            return { r: 0, g: 0, b: 0 }
        if (s.length === 4)
            s = "#" + s[1] + s[1] + s[2] + s[2] + s[3] + s[3]
        return {
            r: parseInt(s.substr(1, 2), 16),
            g: parseInt(s.substr(3, 2), 16),
            b: parseInt(s.substr(5, 2), 16)
        }
    }

    function channel(v) {
        const n = Math.max(0, Math.min(255, Math.round(v)))
        const h = n.toString(16)
        return h.length < 2 ? "0" + h : h
    }

    // Blend a -> b by t, where 0 yields a and 1 yields b.
    function mix(a, b, t) {
        const x = parse(a), y = parse(b)
        return "#" + channel(x.r + (y.r - x.r) * t)
                    + channel(x.g + (y.g - x.g) * t)
                    + channel(x.b + (y.b - x.b) * t)
    }

    // t > 0 lightens toward white, t < 0 darkens toward black.
    function shade(c, t) {
        return t >= 0 ? mix(c, root.white, t) : mix(c, root.black, -t)
    }

    // Perceived brightness, used only to pick a direction.
    function luma(c) {
        const x = parse(c)
        return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b
    }

    // WCAG relative luminance, for choosing text that reads on a fill.
    function relLum(c) {
        const x = parse(c)
        const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(x.r) + 0.7152 * f(x.g) + 0.0722 * f(x.b)
    }

    function contrast(a, b) {
        const la = relLum(a), lb = relLum(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    // Step t *away from* base, whichever direction that is. Keeps the
    // foreground ramp ordered by contrast against the bar background, so it
    // behaves the same on dark themes and light themes.
    function polar(c, t, base) {
        return root.luma(c) >= root.luma(base) ? root.shade(c, t) : root.shade(c, -t)
    }

    // p: anchor object, lit: optional literal overrides
    function build(p, lit) {
        const base = p.base
        const raised = p.raised
        const high = p.high
        const text = p.text
        const muted = p.muted
        const faint = p.faint
        const fg4 = root.mix(muted, faint, 0.45)

        const out = {
            // --- background ramp, darkest -> lightest ---
            // Interpolated between anchors rather than shaded, so the ramp
            // stays monotonic no matter how the anchors are spaced.
            bgD: root.shade(base, -0.05),
            bg: base,
            bgD1: root.mix(base, raised, 0.25),
            bg1: root.mix(base, raised, 0.45),
            bg2: root.mix(base, raised, 0.62),
            bg3: root.mix(base, raised, 0.80),
            bg4: raised,
            bg5: root.mix(raised, high, 0.25),
            bg6: root.mix(raised, high, 0.45),
            bg7: root.mix(raised, high, 0.68),
            bg8: high,
            bg9: root.shade(high, 0.18),

            // --- foreground ramp, most -> least contrast against bg ---
            fgL: root.polar(text, 0.07, base),
            fg1: root.polar(text, 0.06, base),
            fg2: root.polar(text, 0.02, base),
            fg: text,
            fg3: muted,
            fg4: fg4,
            fg5: root.mix(muted, faint, 0.70),
            fg6: faint,
            fg7: root.mix(faint, base, 0.35),
            fg8: root.mix(faint, base, 0.62),
            fg3D: root.mix(muted, faint, 0.35),
            fg4D: root.mix(fg4, text, 0.60),
            sliderBg: root.mix(text, muted, 0.80),

            // --- borders: faint, stepping back toward the bar background ---
            borderBg: faint,
            borderBg1: root.mix(faint, base, 0.50),
            borderBg2: root.mix(faint, base, 0.75),
            borderBg3: root.mix(faint, base, 0.87),
            borderBg4: root.mix(faint, base, 0.93),
            borderBgFocus: root.mix(faint, base, 0.30),
            borderBgFocus1: root.mix(faint, base, 0.40),

            // --- focus / hover surfaces ---
            focusBg: raised,
            focusBg1: root.mix(raised, high, 0.20),
            focusBgD: root.mix(raised, base, 0.30),
            focusBgL: root.mix(raised, high, 0.45),
            focusFg: root.mix(text, muted, 0.20),
            focusFg1: root.mix(muted, faint, 0.15),
            focusFg2: root.mix(muted, faint, 0.38),

            // --- semantic ---
            warning: p.warning,
            deleting: p.danger,
            accent: p.accent,
            coverArtGlowShadow: p.glow || p.accent,

            // --- status / informational ---
            // ok/info are declared per palette; everything else is derived, so a
            // new theme only ever has to name two more anchors.
            // Status tokens step away from the bar background, so a single
            // anchor per theme reads on both light and dark bars -- the same
            // trick the foreground ramp uses.
            okFg: root.polar(p.ok || p.accent, 0.28, base),
            infoFg: root.polar(p.info || p.accent, 0.28, base),
            dangerFg: root.polar(p.danger, 0.28, base),
            warnFg: root.polar(p.warning, 0.28, base),

            // Text or icon drawn on top of an accent-filled surface. Accent is
            // light on dark themes and dark on light themes, so whichever of
            // black / white contrasts more with the accent wins.
            onAccent: root.contrast(root.black, p.accent) >= root.contrast(root.white, p.accent)
                      ? root.black : root.white,

            // Hover state for info-coloured controls. Darkening reads as
            // "pressed" on both polarities, matching the stock behaviour.
            infoHover: root.shade(p.info || p.accent, -0.14),

            // Weather "snow" is near-white in the stock theme and invisible on a
            // light bar. Stepping info away from base keeps the ice-blue hue at
            // a lightness that clears contrast on either polarity.
            weatherSnow: root.polar(p.info || p.accent, 0.26, base)
        }

        // literal overrides win, so stock themes can stay byte-exact
        if (lit) {
            for (const k in lit)
                if (out[k] !== undefined)
                    out[k] = lit[k]
        }
        return out
    }
}
