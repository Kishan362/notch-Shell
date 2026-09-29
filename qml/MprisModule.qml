import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal nowPlaying()

    property bool _wasPlaying: false

    onPlayingChanged: {
        if (playing && !_wasPlaying)
            nowPlaying()
        _wasPlaying = playing
    }

    property var playersList: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activePlayer: resolveActivePlayer()
    property string lastActivePlayerDbusName: ""

    readonly property string track: activePlayer ? (activePlayer.trackTitle || activePlayer.title || "") : ""
    readonly property string artist: {
        if (!activePlayer) return ""
        let a = activePlayer.artist
        if (!a && activePlayer.metadata) a = activePlayer.metadata["xesam:artist"]
        if (a) return Array.isArray(a) ? a.join(", ") : String(a)
        return ""
    }
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || activePlayer.artUrl || "") : ""
    readonly property bool playing: activePlayer ? activePlayer.playbackState === MprisPlaybackState.Playing : false

    readonly property bool hasPlayer: activePlayer !== null && (
        activePlayer.playbackState === MprisPlaybackState.Playing ||
        activePlayer.playbackState === MprisPlaybackState.Paused
    )

    property real polledPosition: 0
    property real polledLength: 0
    readonly property bool lengthKnown: polledLength > 0
    // guard the degenerate length==position case, which otherwise reads as 100%
    readonly property real progress: polledLength > 0 && polledLength > polledPosition
                                ? polledPosition / polledLength : 0

    // Firefox (and some other players) never publish mpris:length. Quickshell's
    // MprisPlayer.length then just mirrors position, so trusting it made the
    // elapsed and total times identical and pinned the progress bar at full.
    // Only accept it when the player says it supports length, then fall back to
    // the metadata field, then admit we do not know.
    function lengthOf(p) {
        if (!p) return 0
        let len = 0
        if (p.lengthSupported) len = Number(p.length) || 0
        if (len <= 0 && p.metadata) len = Number(p.metadata["mpris:length"]) || 0
        // a length equal to the position is the mirror artefact, not a real length
        if (len > 0 && Math.abs(len - (Number(p.position) || 0)) < 0.001) return 0
        return len
    }

    function pollProgress() {
        if (!activePlayer) {
            polledPosition = 0
            polledLength = 0
            return
        }
        polledPosition = Number(activePlayer.position) || 0
        polledLength = lengthOf(activePlayer)
    }

    Timer {
        id: positionTimer
        interval: 1000
        running: root.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollProgress()
    }

    Connections {
        target: root.activePlayer
        function onPositionChanged() { root.pollProgress() }
        function onLengthChanged() { root.pollProgress() }
      }

    function resolveActivePlayer() {
        if (!playersList || playersList.length === 0) return null
        for (let i = 0; i < playersList.length; i++)
            if (playersList[i].playbackState === MprisPlaybackState.Playing)
                return playersList[i]
        const remembered = findByDbus(lastActivePlayerDbusName)
        if (remembered) return remembered
        for (let i = 0; i < playersList.length; i++)
            if (playersList[i].playbackState === MprisPlaybackState.Paused)
                return playersList[i]
        return playersList.length > 0 ? playersList[0] : null
    }

    function findByDbus(name) {
        if (!playersList || !name) return null
        for (let i = 0; i < playersList.length; i++)
            if (playersList[i].dbusName === name) return playersList[i]
        return null
    }

    function playPause() { if (activePlayer && activePlayer.canTogglePlaying) activePlayer.togglePlaying() }
    function next() { if (activePlayer && activePlayer.canGoNext) activePlayer.next() }
    function prev() { if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous() }

    onActivePlayerChanged: {
        if (activePlayer && activePlayer.dbusName)
            lastActivePlayerDbusName = activePlayer.dbusName
    }
}
