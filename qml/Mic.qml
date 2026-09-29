import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Microphone input, mirroring Volume.qml but for Pipewire's default source.
// Bar shows the glyph only (click toggles mute); the level itself is adjusted
// from the slider in the control center.
RowLayout {
  id: root
  signal volumeChanged
  onVolChanged: {
    // resync on external changes (keyboard mic keys, pavucontrol), same as Volume
    if (ready && intendedVol <= 100)
      intendedVol = vol
    root.volumeChanged()
  }
  onMutedChanged: root.volumeChanged()
  onIntendedVolChanged: root.volumeChanged()

  property string fg: Theme.fg
  property string mutedFg: Theme.dangerFg
  property var source: Pipewire.defaultAudioSource
  readonly property bool ready: source && source.ready
  readonly property bool muted: ready && source.audio.muted
  readonly property int vol: ready ? Math.round(source.audio.volume * 100) : 0
  property int intendedVol: vol

  spacing: 4 * Config.paddingScale

  // nf-md-microphone (F036C) / nf-md-microphone_off (F036D).
  // These are Nerd Fonts codepoints, NOT upstream Material Design Icons ones:
  // MDI lists microphone as F029B, but Nerd Fonts remaps its MDI block, and
  // F029B/F029C actually draw a gavel and a Venus symbol here. Always confirm
  // a glyph by rendering it before trusting a codepoint.
  property string icon: {
    const r = ready, m = muted, v = intendedVol   // force-read all deps
    if (!r || m) return String.fromCodePoint(0xf036d)
    if (v === 0) return String.fromCodePoint(0xf036d)
    return String.fromCodePoint(0xf036c)
  }

  function toggleMute() {
    if (!ready) return
    source.audio.muted = !source.audio.muted
  }

  Text {
    text: root.icon
    color: (root.muted || root.vol === 0) ? root.mutedFg : root.fg
    font.family: Theme.nerdFontFamily
    font.pixelSize: 10 * Config.pillScale
  }

  PwObjectTracker {
    objects: [root.source]
  }
}
