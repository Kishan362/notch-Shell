# notch-shell 0.2.1

Fixes dynamic theming so it follows the wallpaper however you change it.

## The theme only followed changes made inside the bar

`refreshWallpaperTheme()` keyed off `currentWallpaper`, and the only thing that
writes that key is notch-shell's own wallpaper switcher. Changing wallpaper by
any other route — a keybind running `awww`, a script, a typed `awww img`, a
file manager action — updated the desktop and left the theme showing the old
palette, with nothing to indicate anything had gone wrong.

The shell now asks `awww query` what is actually on screen and treats that as
the source of truth, falling back to `currentWallpaper` when awww is absent or
its daemon is down. The fallback keeps the switcher working unchanged for anyone
not using awww.

Verified end to end with the config deliberately pointing at the wrong image:
the probe overrode it, and a wallpaper change made from outside the shell was
followed within one poll interval.

## Two bugs found while building it

**The `awww query` parser needed the multiline flag.** `awww` prints one line per
output, and without `/m` the pattern failed to match when the image was on the
first line, and picked the *last* image rather than the first when several
monitors showed different ones. Caught by testing the regex against seven
synthetic outputs rather than only the single-monitor case that happens to be
this machine.

**A sampling flag deadlocked the refresh path.** The guard against overlapping
runs checked `ThemeDynamic.sampling`, which `beginSample()` sets true. On the
wallust path nothing ever cleared it: wallust writes the palette to a file that
`ThemeExternal` reads, so neither `finishSample()` nor `failSample()` is reached.
The flag stayed true and every subsequent wallpaper change was refused. Added
`endSample()` and call it when wallust exits.

That second one is worth dwelling on, because the symptom was the feature
appearing not to work at all while the visible cause — a wallpaper changed
outside the bar — was a separate, already-fixed problem.

---

# notch-shell 0.2.0

Dynamic wallpaper theming. Set `"theme": "wallpaper"` and the bar derives its
palette from the wallpaper, refreshing whenever the wallpaper changes.

## How it works

Palette generation is delegated rather than reimplemented. notch-shell ships a
wallust template that records wallust's 16-colour output verbatim, wallust
writes it to `~/.config/notch-shell/theme-wallust.json`, and the shell watches
that file. Turning those colours into surfaces, text and an accent stays in the
shell, because only the shell knows what those mean for its own UI.

Three tiers, first one available wins:

1. **wallust**, if it is on `$PATH` — the preferred generator.
2. **The built-in sampler**, if ImageMagick is installed.
3. **The default grey theme**, if neither is available.

Uninstalling wallust therefore drops you to the built-in sampler rather than
leaving the bar unthemed, and the ImageMagick sampler is no longer dead code.

The picker shows which generator is live (`source: wallust
salience/saliencedark`). Dynamic theming fails silently often enough that
naming the source is worth the pixels.

## Readability is enforced, not hoped for

Text is pulled 72% of the way to white — or black on a light palette — because a
wallust foreground is tuned to be a legible *terminal* colour, which on a
saturated wallpaper is a fully saturated hue that would tint every label. It is
then walked away from the background until it clears 4.5:1. The accent is the
most chromatic of the 16, corrected until it clears 3:1.

Measured across five wallpapers: text 14.8–18.3:1, accent 5.1–10.9:1.

Accent selection ranks on absolute channel spread rather than the usual
`(max-min)/max` saturation ratio. The ratio scores near-black highly, because a
colour with a zero channel looks saturated however dark it is; on a red wallpaper
it picked `#070001` as the accent, which the contrast fix then washed out to
grey. Spread only counts colour that is actually present.

Status colours are never sampled. A red wallpaper would otherwise paint `danger`
red and make that row invisible.

## Quickshell 0.3.1 traps hit along the way

Three of these cost real debugging time and are worth recording:

- **A `Process` inside a `pragma Singleton` never runs.** It starts, never emits,
  never exits. The sampler had to move into `shell.qml`.
- **Setting `running = false` inside a stream handler kills the process
  mid-flight.** stdout came back empty and the exit code was 15, which reads
  like a broken command rather than a self-inflicted SIGTERM.
- **`FileView.text` is a method in 0.3.1, not a property.** `file.text`
  evaluates to the function object, which stringifies to
  `function text() { [native code] }` and parses as nothing.

## One bug fixed that was already committed

The wallpaper sampler was wired to `Connections { onCurrentWallpaperChanged }`.
That signal never arrives, because `Config` is a lazy singleton and the
wallpaper can appear long after the shell starts. It only ever sampled once, on
whatever happened to be in the config at that instant, and never refreshed
afterwards. It is now polled against the last sampled path.

## Notes

- wallust is not in the Arch repositories, so it is not a package dependency.
  The README documents installing the prebuilt static binary.
- `wallust run` regenerates *every* template in your `wallust.toml`, not just
  notch-shell's. That is normal wallust behaviour but it does mean changing a
  wallpaper here also refreshes anything else you have wired to follow it.
- `imagemagick` stays optional: the wallust path does not use it.

---

# notch-shell 0.1.1

Two fixes to the profile picture picker introduced in 0.1.0. Everything else in
0.1.0 is unchanged.

## The picker never opened

Clicking the avatar did nothing, and nothing was logged to explain it. The
`MouseArea` was a child of the avatar's `ClippingRectangle`, and that type
renders its children through a `ShaderEffectSource`. The hit area therefore sat
in an offscreen subtree and never received a pointer event, so the click fell
through to the dashboard's own toggle and the file dialog was never asked to
open. The `ClippingRectangle` and the hit area are now siblings inside a plain
`Item`, which puts the `MouseArea` back in the scene graph.

## A new picture needed a restart

Even once the dialog opened, the new picture only appeared after restarting the
shell. `set_config.py` wrote the config through a temp file and `os.replace()`,
which swaps the inode. `Config.qml` watches the config path with a `FileView`,
and that is an inotify watch on the inode behind the path, so the first rename
moved the watch onto a file that no longer existed. The first change reached
the shell and every later one was silently dropped.

The write is now done in place, so the inode and the watch both survive. Since
that gives up atomicity, the new text is fully computed before anything is
written, the previous contents are copied to `config.jsonc.bak` first, and the
original is restored if the write does not get far.

---

# notch-shell 0.1.0

First release of **notch-shell**, a Hyprland shell built with
[Quickshell](https://github.com/quickshell-mirror/quickshell): a hanging bar that
hugs the screen edge, 38 themes, two screen-edge notches, and a mini dashboard.

A fork of [ChillPill-Shell](https://github.com/LUCKYS1NGHH/ChillPill-Shell) by
[LUCKYS1NGHH](https://github.com/LUCKYS1NGHH), under the same GPL-3.0 licence.
This release is also a rename: the project was previously called
`chillpill-shell` and it is now **notch-shell** everywhere, including the
package name, the data directory, the config directory and the `notch-shell`
command. Versioning restarts here at `0.1.0`.

## What's new

### Two screen-edge notches

- **Bottom-left: running apps.** Every open window, taskbar style. Grouped by
  app so three kitty windows read as one row with a count badge. The focused
  app is sorted to the top and marked with a dot. Click a row to focus it;
  clicking the row that is already focused is a no-op, so the panel cannot steal
  focus from the window you are typing in.
- **Bottom-right: system tray.** The StatusNotifier icons, left click to
  activate. quickshell registers `org.kde.StatusNotifierWatcher` itself, so no
  separate tray daemon such as `ksni-tray-agent` is required. Note that tray
  apps must be started *after* the shell: they register with the watcher once,
  and an app started while no watcher exists will not appear until restarted.

Both pills are icon-only, hide themselves when there is nothing to show, and
size their panel window to its content so the transparent surface never
swallows clicks on the windows underneath.

### Right-click menus

- **Apps notch.** Right click a row to replace the panel with that window's
  actions: focus, float/unfloat, pin/unpin, enter/exit fullscreen, copy title,
  and close window. Close is drawn in the danger colour and fires immediately,
  with no confirmation step.
- **Tray notch.** Right click an icon to show **the application's own menu**,
  drawn in the shell's styling. This is the real DBusMenu the app publishes,
  not a hardcoded list: separators, disabled rows, checkable items and nested
  submenus all render, and submenus expand inline so the whole menu stays one
  window.

### Light themes are now readable

Fourteen hardcoded near-white text colours across the modules were invisible on
a light bar, several with contrast below 1.2:1 — the same lightness as the
background they sat on. Four dark surfaces had the mirror-image problem.

Every module now reads its colours from the theme system. A new semantic token
layer (`okFg`, `infoFg`, `dangerFg`, `warnFg`, `onAccent`, `infoHover`) sits on
top of the existing ramps, and status tokens step away from the bar background
so a single anchor per theme reads correctly on both light and dark bars.

### 38 themes

`qml/ThemePalettes.qml` holds every palette as ~12 anchor colours, and
`qml/ThemeRamp.qml` expands those into the full property set, so ramps stay
monotonic and consistent across light *and* dark themes. `Theme.qml` became a
dispatcher, so all ~100 existing `Theme.*` call sites are untouched. The
`default` theme reproduces the upstream greys byte-for-byte.

Press <kbd>Super</kbd>+<kbd>T</kbd> for the picker. The `theme` key in
`config.jsonc` is watched, so changes apply without a restart.

`scripts/validate_themes.py` checks every palette for contrast and consistency,
lints against any new hardcoded colour, and asserts that the decorative hues
(weather icons, power-menu accents) still clear 3:1 against the lightest and
darkest bar. All 38 pass.

### CPU stats in the mini dashboard

The right side of the mini dashboard, where the data-usage readout used to be,
now shows CPU utilisation and package temperature. Click or right click the
readout for a per-core breakdown, one bar each; a bar turns red past 85%.

Usage is read from `/proc/stat` through a `FileView`, so a refresh costs one
small read rather than a process spawn, and the percentages are deltas between
samples rather than ratios of counters-since-boot, which would only report
uptime. Temperature comes from `lm_sensors` and hides itself when that is not
installed rather than showing a dash.

The per-core list is capped to whatever height the dashboard actually has, with
the overflow counted as `+N more`; on a 16-core machine the dashboard has room
for about four rows. The module also sits clear of the battery readout, which
occupies the top right.

**nusgmon is no longer a dependency.** It existed only to feed the data-usage
display this replaces.

### Click-to-pick profile picture

Click the avatar in the mini dashboard to choose an image. It is downscaled to
256x256, EXIF rotation applied and centre cropped so the circular avatar never
letterboxes, then cached under `~/.cache/notch-shell/`. `displayPicture` is
repointed at the cached copy by `scripts/set_config.py`, which edits that one
key in place, so comments and formatting in `config.jsonc` survive. `Config.qml`
watches the file, so the new picture appears without a restart.

That script rewrites the config rather than swapping it via a temp file and
rename. `Config.qml` watches the path with a `FileView`, which is an inotify
watch on the inode behind it, and `os.replace()` moves that watch onto the old,
now-deleted file. The first change reached the shell and every later one was
silently ignored, so a newly picked picture only appeared after a restart. The
write is now in place, and a `config.jsonc.bak` is left behind each time.

ImageMagick does the resize and is an optional dependency. Without it the
picked file is used where it lies, so picking a picture still works, it is just
not shrunk.

This needs the xdg-desktop-portal Qt platform theme, which `launcher.sh` now
sets when it is not already configured. Without it Qt's file dialog opens
invisibly and the button appears to do nothing.

### Other changes

- **Display name** is Notch Shell, and the launcher, desktop entry, data
  directory, config directory and cache directory all follow the
  `notch-shell` name.
- **Nightlight and Caffeine** replace lock and sleep in the mini dashboard.
  <kbd>Super</kbd>+<kbd>N</kbd> toggles the nightlight, which drives
  `wlsunset` with a day temperature above the night one — passing equal values
  makes wlsunset refuse silently.
- **Media polling halved.** The MPRIS module and the media popup moved from a
  500 ms to a 1000 ms interval.
- **Control centre is lazy-loaded.** Its body sits behind a `Loader` that
  activates on first use, which saves roughly 4 MB of resident memory.

## Upgrading from chillpill-shell

The old package is a different name, so it will not be replaced in place.
Remove it first, then install this one:

```bash
sudo pacman -Rns chillpill-shell
cp -r ~/.config/chillpill-shell ~/.config/notch-shell
sudo pacman -U ./notch-shell-0.1.0-1-x86_64.pkg.tar.zst
```

Your existing settings carry over: only the directory name changes. Delete
`~/.config/chillpill-shell` once you are satisfied.

## Install

### Arch (recommended)

Grab the attached `notch-shell-0.1.0-1-x86_64.pkg.tar.zst` and:

```bash
sudo pacman -U ./notch-shell-0.1.0-1-x86_64.pkg.tar.zst
```

This replaces the AUR `notch-shell`; your `~/.config/notch-shell` is
left untouched. Roll back with `yay -S notch-shell`.

### Dependencies

`cliphist` · `nusgmon-git` · `inotify-tools` · `brightnessctl` ·
`wl-clipboard` · `quickshell` (>= 0.3.0) · `qt6-multimedia` · `qt6-wayland` ·
`hyprland` · `pipewire` · `awww` · `networkmanager`

Optional: `ttf-jetbrains-mono-nerd`, `ttf-monocraft-nerd`, `qt6-imageformats`,
`python-pip` (for `holidays`), `cava` (audio visualiser).

### Two setup steps worth doing

```bash
# cliphist 0.7 dropped the "cliphist daemon" subcommand; without the watcher
# the clipboard manager stays permanently empty
printf 'wl-paste --watch cliphist store >/dev/null 2>&1 &\n'   # add to your Hyprland autostart

sudo nusgmon    # one-time; creates its data-usage directories
```

## Key bindings

None of the shell's panels are auto-started; each is opened from a key. Bind
them in your Hyprland config (`hyprland.lua` for the Lua config):

```lua
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc -p /usr/share/notch-shell call controlCenter toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc -p /usr/share/notch-shell call cliphist toggle"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("qs ipc -p /usr/share/notch-shell call appLauncher toggle"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc -p /usr/share/notch-shell call wallpaperSwitcher toggle"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("qs ipc -p /usr/share/notch-shell call themePicker toggle"))
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("qs ipc -p /usr/share/notch-shell call weather toggle"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs ipc -p /usr/share/notch-shell call powerMenu toggle"))
```

| Target | Default | Opens |
| --- | --- | --- |
| `controlCenter` | <kbd>Super</kbd>+<kbd>C</kbd> | Control centre: sliders, media, notifications |
| `cliphist` | <kbd>Super</kbd>+<kbd>V</kbd> | Clipboard manager |
| `appLauncher` | <kbd>Super</kbd>+<kbd>R</kbd> | App launcher |
| `wallpaperSwitcher` | <kbd>Super</kbd>+<kbd>W</kbd> | Wallpaper switcher |
| `themePicker` | <kbd>Super</kbd>+<kbd>T</kbd> | **Theme picker** (this fork) |
| `weather` | <kbd>Super</kbd>+<kbd>Y</kbd> | **Weather popup** (this fork) |
| `powerMenu` | <kbd>Super</kbd>+<kbd>Esc</kbd> | Lock / sleep / logout / restart / shutdown |
| `miniDashboard` | unbound | System info; also right-click the bar |

Every target also accepts `show` and `hide` in place of `toggle`.

`weather` is new in this fork. It is not bound by upstream, and without a bind
the popup is still reachable by right-clicking the bar and clicking the weather
in the mini dashboard — binding it is just more convenient.

**Escape closes any open panel**, so you rarely need a dedicated close key. In
the location picker it steps back one level (cancels the search) before closing
the popup. The power menu is the exception: its first Escape cancels a pending
confirmation rather than closing, which is deliberate.

### Reaching the new features without a keybind

Two of them need no binding at all:

- **Location picker** — click the city name in the weather popup
- **Mic** — click the mic icon in the bar to mute/unmute; drag its slider in the
  control centre
- **Wifi** — click the icon in the bar to toggle Wi-Fi; hover any bar module for
  a tooltip

## What's new

### Light themes are now actually light

Previously 14 text colours across the modules were hardcoded near-white, so on a
light bar they were invisible — several had contrast below 1.2:1, the same
lightness as the background they sat on. Four dark surfaces had the same
problem in reverse on dark themes.

Every module now reads its colours from the theme system. A new semantic token
layer (`okFg`, `infoFg`, `dangerFg`, `warnFg`, `onAccent`, `weatherSnow`) sits on
top of the existing ramps; status tokens step away from the bar background so one
anchor per theme reads on both light and dark bars.
`scripts/validate_themes.py` checks every palette for contrast and consistency,
and lints against any new hardcoded colour.

### 38 themes, switchable live

`qml/ThemePalettes.qml` holds every palette as ~12 anchor colours;
`qml/ThemeRamp.qml` expands those into the full property set, so ramps stay
monotonic and consistent across light *and* dark themes. `Theme.qml` became a
dispatcher, so all ~100 existing `Theme.*` call sites are untouched.

Press <kbd>Super</kbd>+<kbd>T</kbd> for the picker. The `theme` key in
`config.jsonc` is watched, so changes apply without a restart. `default`
reproduces the upstream greys byte-for-byte.

Included: Nord, Nord Light, Gruvbox, Gruvbox Light, Gruvbox Hard, Catppuccin
Mocha/Macchiato/Frappé/Latte, Tokyo Night/Storm/Light, Dracula, Rosé Pine,
Rosé Pine Dawn, Rosé Pine Moon, Everforest, Kanagawa, Ayu Mirage, Ayu Dark,
Ayu Light, One Dark, One Light, Solarized Dark, Solarized Light, Material
Ocean, Material Palenight, Material Light, Monokai, GitHub Dark, GitHub Light,
Vitesse Dark, Vitesse Light, Nightfox, Dayfox, Builtin Dark, Builtin Light.

### Hanging bar

The bar attaches to the top edge — square top corners, rounded bottom — in
every state, via per-corner radii (needs Qt >= 6.7).

### Mic module

`Mic.qml` drives `Pipewire.defaultAudioSource`, with a slider in the control
centre. The volume percentage was removed from the speaker module; the glyph
already encodes level and mute.

### Wifi indicator and separators

`Wifi.qml` shows signal tiers without the SSID (`network` still gives the name
inline if you prefer it), and `Separator.qml` divides groups. Default order:

```
wifi · battery · │ · volume mic · │ · workspaces · │ · clock
```

### Weather location picker

Click the city name in the weather popup to search. Results are disambiguated
through Open-Meteo geocoding, so `Delhi` offers Delhi in India *and* the five in
the US. A pick stores both a readable name and `lat,lon` so later fetches are
exact rather than re-guessed. A crosshairs button detects by IP.

`scripts/set_config.py` edits `config.jsonc` in place, preserving comments and
value types.

### Notification sound

`scripts/make_notification_sound.py` synthesises the chime, so no opaque binary
blob is committed.

### Escape closes anything

Any open overlay now closes on Escape, stepping back one level in the location
editor first. The power menu is excluded on purpose — its Escape is two-stage,
cancelling a pending confirmation before closing.

## Bugs fixed

- **`pillTopMargin: 0` was ignored on cold start**, leaving the bar 9px below
  the screen edge — so the notch never touched the display. The config loads
  asynchronously, so the layer-shell surface was first committed with the
  pre-load fallback of 9, and wlr-layer-shell never re-applies a margin change
  *to zero*.
- **The control centre clipped the brightness slider** when media was playing;
  the with-player height did not account for the third slider row.
- **Firefox reports no track length.** It never publishes `mpris:length`, and
  Quickshell's `MprisPlayer.length` then mirrors position — so the media card
  printed the elapsed time on both sides and the seek bar sat permanently full.
  It now shows `--:--` when the length is genuinely unknown, and seeking no
  longer misbehaves.
- **Misleading nusgmon errors.** nusgmon answers with plain text on stdout when
  uninitialised, which was fed straight to `JSON.parse`. The real message is
  surfaced now.
- **Missing compose file** for locales like `en_IN` made Qt log errors whenever
  a text field took focus; the launcher points `XCOMPOSE` at a locale that has
  one.

## Known limitations

- Decorative hues whose meaning is the hue itself (the sun/rain weather icons,
  the power-menu action accents) stay literal. They're mid-tone so they read on
  any bar, and `scripts/validate_themes.py` proves each clears 3:1 against the
  lightest and darkest backgrounds in the set.
- IP location detection reflects how your ISP routes you — treat it as a
  starting point. The search box is the reliable path.
- Three Qt warnings remain that aren't attributable to this code:
  `qt.svg.draw` (oversized icon request at startup), `QIODevice::read` on an
  HTTP socket during teardown, and an `iwd` D-Bus probe.
