pragma Singleton
import Quickshell
import QtQuick

// Every selectable theme, as data.
//
// Each entry declares ~10 anchor colors. ThemeRamp.build() expands those into
// the full Theme property set, so a palette is cheap to add and impossible to
// get internally inconsistent.
//
//   base/raised/high  background ramp anchors, ordered dark -> light
//   text/muted/faint  foreground ramp anchors, ordered light -> dark
//   accent            highlight: cava visualizer bars, notification links
//   warning/danger    low battery, delete confirmations
//   glow              album-art glow (falls back to accent)
//
// A theme may add a `literal` object to pin individual values; those override
// the derived ramp. "default" does this to reproduce the stock greys exactly.
//
// `swatches` is stored precomputed (base, raised, accent, text) so the picker
// can draw without running the ramp for every theme.
//
// Adding a theme: copy any block below, give it a key, and set label/light.
// The key is what goes in the "theme" key of config.jsonc.
Singleton {
    id: root

    readonly property var themes: ({

        // ---------------------------------------------------------- default
        "default": {
            label: "Default",
            light: false,
            swatches: ["#161616", "#282828", "#979797", "#dadada"],
            palette: {
                base: "#161616",
                raised: "#282828",
                high: "#454545",
                text: "#dadada",
                muted: "#c4c4c4",
                faint: "#6a6a6a",
                accent: "#979797",
                warning: "#fac94a",
                danger: "#e32626",
                glow: "#80aae6", ok: "#4bd25c", info: "#6791dc"
            },
            // exact upstream values, so "default" is pixel-identical to stock
            literal: {
                bg: "#161616",
                bg1: "#212121",
                bg2: "#232323",
                bg3: "#252525",
                bg4: "#282828",
                bg5: "#323232",
                bg6: "#353535",
                bg7: "#404040",
                bg8: "#454545",
                bg9: "#505050",
                bgD: "#141414",
                bgD1: "#191919",
                fg: "#dadada",
                fg1: "#e7e7e7",
                fg2: "#dfdfdf",
                fg3: "#c4c4c4",
                fg4: "#9e9e9e",
                fg5: "#777777",
                fg6: "#6a6a6a",
                fg7: "#484848",
                fg8: "#313131",
                fgL: "#e9e9e9",
                sliderBg: "#c9c9c9",
                fg3D: "#a7a7a7",
                fg4D: "#c5c4c4",
                borderBg: "#6a6a6a",
                borderBg1: "#484848",
                borderBg2: "#323232",
                borderBg3: "#282828",
                borderBg4: "#242424",
                borderBgFocus: "#555555",
                borderBgFocus1: "#4f4f4f",
                focusBg: "#282828",
                focusBg1: "#2e2e2e",
                focusBgD: "#222222",
                focusBgL: "#353535",
                focusFg: "#d1d1d1",
                focusFg1: "#bcbcbc",
                focusFg2: "#a8a8a8",
                warning: "#fac94a",
                deleting: "#e32626",
                accent: "#979797",
                coverArtGlowShadow: "#80aae6",
                okFg: "#4bd25c",
                infoFg: "#6791dc",
                dangerFg: "#e32626",
                warnFg: "#fac94a",
                infoHover: "#3065be",
                weatherSnow: "#d8e8f4"
            }
        },

        // ------------------------------------------------------------- nord
        "nord": {
            label: "Nord",
            light: false,
            swatches: ["#2e3440", "#3b4252", "#88c0d0", "#eceff4"],
            palette: {
                base: "#2e3440", raised: "#3b4252", high: "#434c5e",
                text: "#eceff4", muted: "#d8dee9", faint: "#4c566a",
                accent: "#88c0d0", warning: "#ebcb8b", danger: "#bf616a", glow: "#81a1c1", ok: "#a3be8c", info: "#81a1c1"
            }
        },
        "nord-light": {
            label: "Nord Light",
            light: true,
            swatches: ["#e5e9f0", "#eef2f8", "#5e81ac", "#2e3440"],
            palette: {
                base: "#e5e9f0", raised: "#eef2f8", high: "#f8fafc",
                text: "#2e3440", muted: "#4c566a", faint: "#a9b3c1",
                accent: "#5e81ac", warning: "#b58900", danger: "#bf616a", glow: "#81a1c1", ok: "#a3be8c", info: "#5e81ac"
            }
        },

        // ---------------------------------------------------------- gruvbox
        "gruvbox": {
            label: "Gruvbox",
            light: false,
            swatches: ["#282828", "#3c3836", "#fe8019", "#ebdbb2"],
            palette: {
                base: "#282828", raised: "#3c3836", high: "#504945",
                text: "#ebdbb2", muted: "#d5c4a1", faint: "#928374",
                accent: "#fe8019", warning: "#fabd2f", danger: "#fb4934", glow: "#83a598", ok: "#b8bb26", info: "#83a598"
            }
        },
        "gruvbox-light": {
            label: "Gruvbox Light",
            light: true,
            swatches: ["#f4e9c0", "#faf3d8", "#af3a03", "#3c3836"],
            palette: {
                base: "#f4e9c0", raised: "#faf3d8", high: "#fdf9e8",
                text: "#3c3836", muted: "#5a5241", faint: "#b0a181",
                accent: "#af3a03", warning: "#b57614", danger: "#cc241d", glow: "#076678", ok: "#79740e", info: "#076678"
            }
        },

        // -------------------------------------------------------- catppuccin
        "catppuccin-mocha": {
            label: "Catppuccin Mocha",
            light: false,
            swatches: ["#1e1e2e", "#313244", "#cba6f7", "#cdd6f4"],
            palette: {
                base: "#1e1e2e", raised: "#313244", high: "#45475a",
                text: "#cdd6f4", muted: "#bac2de", faint: "#585b70",
                accent: "#cba6f7", warning: "#f9e2af", danger: "#f38ba8", glow: "#89b4fa", ok: "#a6e3a1", info: "#89b4fa"
            }
        },
        "catppuccin-macchiato": {
            label: "Catppuccin Macchiato",
            light: false,
            swatches: ["#24273a", "#363a4f", "#c6a0f6", "#cad3f5"],
            palette: {
                base: "#24273a", raised: "#363a4f", high: "#494d64",
                text: "#cad3f5", muted: "#b8c0e0", faint: "#5b6078",
                accent: "#c6a0f6", warning: "#eed49f", danger: "#ed8796", glow: "#8aadf4", ok: "#a6da95", info: "#8aadf4"
            }
        },
        "catppuccin-frappe": {
            label: "Catppuccin Frappé",
            light: false,
            swatches: ["#303446", "#414559", "#ca9ee6", "#c6d0f5"],
            palette: {
                base: "#303446", raised: "#414559", high: "#51576d",
                text: "#c6d0f5", muted: "#b5bfe2", faint: "#626880",
                accent: "#ca9ee6", warning: "#e5c890", danger: "#e78284", glow: "#8caaee", ok: "#a6d189", info: "#8caaee"
            }
        },
        "catppuccin-latte": {
            label: "Catppuccin Latte",
            light: true,
            swatches: ["#e6e9ef", "#eff1f5", "#8839ef", "#4c4f69"],
            palette: {
                base: "#e6e9ef", raised: "#eff1f5", high: "#f7f8fb",
                text: "#4c4f69", muted: "#6c6f85", faint: "#b4b9c6",
                accent: "#8839ef", warning: "#df8e1d", danger: "#d20f39", glow: "#1e66f5", ok: "#40a02b", info: "#1e66f5"
            }
        },

        // ------------------------------------------------------- tokyo night
        "tokyo-night": {
            label: "Tokyo Night",
            light: false,
            swatches: ["#1a1b26", "#24283b", "#7aa2f7", "#c0caf5"],
            palette: {
                base: "#1a1b26", raised: "#24283b", high: "#414868",
                text: "#c0caf5", muted: "#a9b1d6", faint: "#565f89",
                accent: "#7aa2f7", warning: "#e0af68", danger: "#f7768e", glow: "#7dcfff", ok: "#9ece6a", info: "#7aa2f7"
            }
        },
        "tokyo-night-storm": {
            label: "Tokyo Night Storm",
            light: false,
            swatches: ["#24283b", "#292e42", "#7aa2f7", "#c0caf5"],
            palette: {
                base: "#24283b", raised: "#292e42", high: "#3b4261",
                text: "#c0caf5", muted: "#a9b1d6", faint: "#565f89",
                accent: "#7aa2f7", warning: "#e0af68", danger: "#f7768e", glow: "#7dcfff", ok: "#9ece6a", info: "#7aa2f7"
            }
        },
        "tokyo-night-light": {
            label: "Tokyo Night Light",
            light: true,
            swatches: ["#d5d6db", "#e1e2e7", "#2e7de9", "#343b58"],
            palette: {
                base: "#d5d6db", raised: "#e1e2e7", high: "#edeef2",
                text: "#343b58", muted: "#4a5570", faint: "#a3a7b8",
                accent: "#1f6fe0", warning: "#8c6c3e", danger: "#f52a65", glow: "#007197", ok: "#587539", info: "#2e7de9"
            }
        },

        // ------------------------------------------------------------ dracula
        "dracula": {
            label: "Dracula",
            light: false,
            swatches: ["#282a36", "#343746", "#bd93f9", "#f8f8f2"],
            palette: {
                base: "#282a36", raised: "#343746", high: "#44475a",
                text: "#f8f8f2", muted: "#d6d8de", faint: "#6272a4",
                accent: "#bd93f9", warning: "#f1fa8c", danger: "#ff5555", glow: "#8be9fd", ok: "#50fa7b", info: "#8be9fd"
            }
        },

        // ---------------------------------------------------------- rose pine
        "rose-pine": {
            label: "Rosé Pine",
            light: false,
            swatches: ["#191724", "#1f1d2e", "#c4a7e7", "#e0def4"],
            palette: {
                base: "#191724", raised: "#1f1d2e", high: "#26233a",
                text: "#e0def4", muted: "#908caa", faint: "#6e6a86",
                accent: "#c4a7e7", warning: "#f6c177", danger: "#eb6f92", glow: "#31748f", ok: "#9ccfd8", info: "#31748f"
            }
        },
        "rose-pine-dawn": {
            label: "Rosé Pine Dawn",
            light: true,
            swatches: ["#f2e9e1", "#faf4ed", "#907aa9", "#575279"],
            palette: {
                base: "#f2e9e1", raised: "#faf4ed", high: "#fffaf5",
                text: "#575279", muted: "#6e6a86", faint: "#c4b8c9",
                accent: "#907aa9", warning: "#ea9d34", danger: "#b4637a", glow: "#56949f", ok: "#56949f", info: "#286983"
            }
        },

        // ---------------------------------------------------------- everforest
        "everforest": {
            label: "Everforest",
            light: false,
            swatches: ["#2d353b", "#343f44", "#a7c080", "#d3c6aa"],
            palette: {
                base: "#2d353b", raised: "#343f44", high: "#3d484d",
                text: "#d3c6aa", muted: "#9da9a0", faint: "#859289",
                accent: "#a7c080", warning: "#dbbc7f", danger: "#e67e80", glow: "#7fbbb3", ok: "#a7c080", info: "#7fbbb3"
            }
        },

        // ----------------------------------------------------------- kanagawa
        "kanagawa": {
            label: "Kanagawa",
            light: false,
            swatches: ["#1f1f28", "#2a2a37", "#7e9cd8", "#dcd7ba"],
            palette: {
                base: "#1f1f28", raised: "#2a2a37", high: "#363646",
                text: "#dcd7ba", muted: "#c8c093", faint: "#727169",
                accent: "#7e9cd8", warning: "#e6c384", danger: "#e82424", glow: "#7aa89f", ok: "#98bb6c", info: "#7e9cd8"
            }
        },

        // --------------------------------------------------------------- ayu
        "ayu-mirage": {
            label: "Ayu Mirage",
            light: false,
            swatches: ["#1f2430", "#273340", "#ffcc66", "#cbccc6"],
            palette: {
                base: "#1f2430", raised: "#273340", high: "#3d4757",
                text: "#cbccc6", muted: "#b3b1a1", faint: "#5c6773",
                accent: "#ffcc66", warning: "#ffd173", danger: "#f26d78", glow: "#90e1c6", ok: "#a5c261", info: "#5ccfe6"
            }
        },

        // ----------------------------------------------------------- one dark
        "one-dark": {
            label: "One Dark",
            light: false,
            swatches: ["#282c34", "#2c313c", "#61afef", "#abb2bf"],
            palette: {
                base: "#282c34", raised: "#2c313c", high: "#3e4451",
                text: "#abb2bf", muted: "#9da5b4", faint: "#4b5263",
                accent: "#61afef", warning: "#e5c07b", danger: "#e06c75", glow: "#56b6c2", ok: "#98c379", info: "#61afef"
            }
        },

        // ---------------------------------------------------------- solarized
        "solarized-dark": {
            label: "Solarized Dark",
            light: false,
            swatches: ["#002b36", "#073642", "#268bd2", "#93a1a1"],
            palette: {
                base: "#002b36", raised: "#073642", high: "#586e75",
                text: "#93a1a1", muted: "#839496", faint: "#586e75",
                accent: "#268bd2", warning: "#b58900", danger: "#dc322f", glow: "#2aa198", ok: "#859900", info: "#268bd2"
            }
        },

        // ------------------------------------------------------------ material
        "material-ocean": {
            label: "Material Ocean",
            light: false,
            swatches: ["#0f1117", "#1b1f27", "#89b4fa", "#c3c8d4"],
            palette: {
                base: "#0f1117", raised: "#1b1f27", high: "#262b36",
                text: "#c3c8d4", muted: "#a2a8b8", faint: "#5c6370",
                accent: "#89b4fa", warning: "#f9e2af", danger: "#f07178", glow: "#89dceb", ok: "#c3e88d", info: "#82aaff"
            }
        },

        // ------------------------------------------------------------- monokai
        "monokai": {
            label: "Monokai",
            light: false,
            swatches: ["#272822", "#2f302a", "#a6e22e", "#f8f8f2"],
            palette: {
                base: "#272822", raised: "#2f302a", high: "#3e3d32",
                text: "#f8f8f2", muted: "#cfcfc2", faint: "#75715e",
                accent: "#a6e22e", warning: "#e6db74", danger: "#f92672", glow: "#66d9ef", ok: "#a6e22e", info: "#66d9ef"
            }
        },

        // ------------------------------------------------------------- github
        "github-dark": {
            label: "GitHub Dark",
            light: false,
            swatches: ["#0d1117", "#161b22", "#58a6ff", "#e6edf3"],
            palette: {
                base: "#0d1117", raised: "#161b22", high: "#21262d",
                text: "#e6edf3", muted: "#8b949e", faint: "#484f58",
                accent: "#58a6ff", warning: "#d29922", danger: "#f85149", glow: "#1f6feb", ok: "#3fb950", info: "#58a6ff"
            }
        },
        "github-light": {
            label: "GitHub Light",
            light: true,
            swatches: ["#f6f8fa", "#ffffff", "#0969da", "#1f2328"],
            palette: {
                base: "#f6f8fa", raised: "#ffffff", high: "#ffffff",
                text: "#1f2328", muted: "#59636e", faint: "#d1d9e0",
                accent: "#0969da", warning: "#9a6700", danger: "#d1242f", glow: "#0969da", ok: "#1a7f37", info: "#0969da"
            }
        },

        // ------------------------------------------------------------ vitesse
        "vitesse-dark": {
            label: "Vitesse Dark",
            light: false,
            swatches: ["#121212", "#1c1c1c", "#7aa2f7", "#dbd7ca"],
            palette: {
                base: "#121212", raised: "#1c1c1c", high: "#2a2a2a",
                text: "#dbd7ca", muted: "#b0ada2", faint: "#5c5c5c",
                accent: "#7aa2f7", warning: "#e0af68", danger: "#f7768e", glow: "#7dcfff", ok: "#9ece6a", info: "#7dcfff"
            }
        },
        "vitesse-light": {
            label: "Vitesse Light",
            light: true,
            swatches: ["#f5f5f5", "#ffffff", "#3461d1", "#393a34"],
            palette: {
                base: "#f5f5f5", raised: "#ffffff", high: "#ffffff",
                text: "#393a34", muted: "#6e6e6e", faint: "#a0a0a0",
                accent: "#3461d1", warning: "#8a6d00", danger: "#ab2b2b", glow: "#2e7de9", ok: "#567a39", info: "#3461d1"
            }
        },

        // ---------------------------------------------------------------- ayu
        "ayu-dark": {
            label: "Ayu Dark",
            light: false,
            swatches: ["#0a0e14", "#11151c", "#e6b450", "#b3b1ad"],
            palette: {
                base: "#0a0e14", raised: "#11151c", high: "#1c212b",
                text: "#b3b1ad", muted: "#8a9199", faint: "#3d424d",
                accent: "#e6b450", warning: "#ffb454", danger: "#ff3333", glow: "#59c2ff", ok: "#c2d94c", info: "#59c2ff"
            }
        },
        "ayu-light": {
            label: "Ayu Light",
            light: true,
            swatches: ["#f0f0f0", "#ffffff", "#c78900", "#5c6166"],
            palette: {
                base: "#f0f0f0", raised: "#ffffff", high: "#ffffff",
                text: "#4e5459", muted: "#8a9199", faint: "#c0c0c0",
                accent: "#ad7800", warning: "#ff8c00", danger: "#ff3333", glow: "#399ee6", ok: "#86b300", info: "#399ee6"
            }
        },

        // ----------------------------------------------------------- nightfox
        "nightfox": {
            label: "Nightfox",
            light: false,
            swatches: ["#192330", "#212b3b", "#63cdcf", "#cdcecf"],
            palette: {
                base: "#192330", raised: "#212b3b", high: "#293342",
                text: "#cdcecf", muted: "#8b9ba8", faint: "#4d5b6a",
                accent: "#63cdcf", warning: "#dbc074", danger: "#f16d82", glow: "#82b1ff", ok: "#8dba8c", info: "#63cdcf"
            }
        },
        "dayfox": {
            label: "Dayfox",
            light: true,
            swatches: ["#f6f2ee", "#fefaf6", "#287980", "#2b303b"],
            palette: {
                base: "#f6f2ee", raised: "#fefaf6", high: "#ffffff",
                text: "#2b303b", muted: "#5d6570", faint: "#c8c0ba",
                accent: "#287980", warning: "#8a6d00", danger: "#b3434f", glow: "#5a7ab5", ok: "#396847", info: "#287980"
            }
        },

        // ----------------------------------------------------------- material
        "material-palenight": {
            label: "Material Palenight",
            light: false,
            swatches: ["#292d3e", "#343a4c", "#82aaff", "#a6accd"],
            palette: {
                base: "#292d3e", raised: "#343a4c", high: "#3f465c",
                text: "#a6accd", muted: "#676e95", faint: "#4b5270",
                accent: "#82aaff", warning: "#ffcb6b", danger: "#f07178", glow: "#89ddff", ok: "#c3e88d", info: "#82aaff"
            }
        },
        "material-light": {
            label: "Material Light",
            light: true,
            swatches: ["#f0f0f0", "#ffffff", "#1976d2", "#212121"],
            palette: {
                base: "#f0f0f0", raised: "#ffffff", high: "#ffffff",
                text: "#212121", muted: "#616161", faint: "#bdbdbd",
                accent: "#1976d2", warning: "#f57c00", danger: "#d32f2f", glow: "#0288d1", ok: "#388e3c", info: "#1976d2"
            }
        },

        // ------------------------------------------------------------ builtin
        "builtin-dark": {
            label: "Builtin Dark",
            light: false,
            swatches: ["#1e1e1e", "#252526", "#569cd6", "#d4d4d4"],
            palette: {
                base: "#1e1e1e", raised: "#252526", high: "#2d2d30",
                text: "#d4d4d4", muted: "#9d9d9d", faint: "#3c3c3c",
                accent: "#569cd6", warning: "#dcdcaa", danger: "#f44747", glow: "#4ec9b0", ok: "#6a9955", info: "#569cd6"
            }
        },
        "builtin-light": {
            label: "Builtin Light",
            light: true,
            swatches: ["#f3f3f3", "#ffffff", "#005fb8", "#1e1e1e"],
            palette: {
                base: "#f3f3f3", raised: "#ffffff", high: "#ffffff",
                text: "#1e1e1e", muted: "#6a6a6a", faint: "#d4d4d4",
                accent: "#005fb8", warning: "#795e26", danger: "#c72e0f", glow: "#005fb8", ok: "#107c10", info: "#005fb8"
            }
        },

        // ---------------------------------------------------------- solarized
        "solarized-light": {
            label: "Solarized Light",
            light: true,
            swatches: ["#eee8d5", "#fdf6e3", "#268bd2", "#586e75"],
            palette: {
                base: "#eee8d5", raised: "#fdf6e3", high: "#fdf6e3",
                text: "#49585e", muted: "#5f7076", faint: "#d8d2bc",
                accent: "#268bd2", warning: "#b58900", danger: "#dc322f", glow: "#2aa198", ok: "#859900", info: "#268bd2"
            }
        },

        // ---------------------------------------------------------- rose pine
        "rose-pine-moon": {
            label: "Rosé Pine Moon",
            light: false,
            swatches: ["#232136", "#2a273f", "#c4a7e7", "#e0def4"],
            palette: {
                base: "#232136", raised: "#2a273f", high: "#393552",
                text: "#e0def4", muted: "#908caa", faint: "#6e6a86",
                accent: "#c4a7e7", warning: "#f6c177", danger: "#eb6f92", glow: "#3e8fb0", ok: "#9ccfd8", info: "#3e8fb0"
            }
        },

        // ----------------------------------------------------------- one dark
        "one-light": {
            label: "One Light",
            light: true,
            swatches: ["#f0f0f0", "#ffffff", "#4078f2", "#383a42"],
            palette: {
                base: "#f0f0f0", raised: "#ffffff", high: "#ffffff",
                text: "#383a42", muted: "#696c77", faint: "#a0a1a7",
                accent: "#4078f2", warning: "#c18401", danger: "#e45649", glow: "#0184bc", ok: "#50a14f", info: "#4078f2"
            }
        },

        // ------------------------------------------------------------ gruvbox
        "gruvbox-hard": {
            label: "Gruvbox Hard",
            light: false,
            swatches: ["#1d2021", "#282828", "#fe8019", "#ebdbb2"],
            palette: {
                base: "#1d2021", raised: "#282828", high: "#3c3836",
                text: "#ebdbb2", muted: "#d5c4a1", faint: "#928374",
                accent: "#fe8019", warning: "#fabd2f", danger: "#fb4934", glow: "#83a598", ok: "#b8bb26", info: "#83a598"
            }
        }
    })

    // Unknown / missing names fall back to default rather than breaking the UI.
    function get(name) {
        const t = root.themes[String(name).toLowerCase()]
        return t !== undefined ? t : root.themes["default"]
    }

    function names() {
        return Object.keys(root.themes)
    }
}
