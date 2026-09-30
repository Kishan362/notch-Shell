pragma Singleton
import Quickshell
import QtQuick

// Resolves the active theme and exposes it as flat properties.
//
// The property names below are the shell's stable theme API: every other QML
// file reads Theme.bg5, Theme.fg3, Theme.accent and so on. Swapping themes
// re-binds these against a different palette without touching any call site.
Singleton {
    id: root

    // "wallpaper" is not in the table: it is generated from the current
    // wallpaper on demand. Everything downstream is unchanged, because
    // ThemeDynamic.entry has the same shape a table entry has.
    readonly property var entry: Config.theme === ThemeDynamic.themeName
        ? (ThemeDynamic.entry || ThemePalettes.get("default"))
        : ThemePalettes.get(Config.theme)
    readonly property string name: Config.theme
    readonly property var p: ThemeRamp.build(entry.palette, entry.literal)

    // --- background ramp (more darker, descending) ---
    property string bg: p.bg
    property string bg1: p.bg1
    property string bg2: p.bg2
    property string bg3: p.bg3
    property string bg4: p.bg4
    property string bg5: p.bg5
    property string bg6: p.bg6
    property string bg7: p.bg7
    property string bg8: p.bg8
    property string bg9: p.bg9

    property string bgD: p.bgD
    property string bgD1: p.bgD1

    // --- foreground ramp (more darker, ascending) ---
    property string fg: p.fg
    property string fg1: p.fg1
    property string fg2: p.fg2
    property string fg3: p.fg3
    property string fg4: p.fg4
    property string fg5: p.fg5
    property string fg6: p.fg6
    property string fg7: p.fg7
    property string fg8: p.fg8
    property string fgL: p.fgL

    // CC sliders
    property string sliderBg: p.sliderBg

    property string fg3D: p.fg3D
    property string fg4D: p.fg4D

    property string borderBg: p.borderBg
    property string borderBg1: p.borderBg1
    property string borderBg2: p.borderBg2
    property string borderBg3: p.borderBg3
    property string borderBg4: p.borderBg4
    property string borderBgFocus: p.borderBgFocus
    property string borderBgFocus1: p.borderBgFocus1

    // focus bg
    property string focusBg: p.focusBg
    property string focusBg1: p.focusBg1
    property string focusBgD: p.focusBgD
    property string focusBgL: p.focusBgL

    property string focusFg: p.focusFg
    property string focusFg1: p.focusFg1
    property string focusFg2: p.focusFg2

    property string fontFamily: Config.textFontFamily
    property string nerdFontFamily: Config.nerdFontFamily

    property string warning: p.warning
    property string deleting: p.deleting

    property string accent: p.accent
    property string coverArtGlowShadow: p.coverArtGlowShadow

    // status / informational
    property string okFg: p.okFg
    property string infoFg: p.infoFg
    property string dangerFg: p.dangerFg
    property string warnFg: p.warnFg
    property string onAccent: p.onAccent
    property string infoHover: p.infoHover
    property string weatherSnow: p.weatherSnow

    property int fontSizeBase: 13
    property int fontSize: Math.round(fontSizeBase * Config.pillScale)
}
