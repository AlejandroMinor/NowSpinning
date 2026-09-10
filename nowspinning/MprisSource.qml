// The data source. Isolates everything that knows about MPRIS, so neither the
// window nor the skins ever have to know about D-Bus.
import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    // Preferred bus name, set from config.json's `preferredPlayer`. Wins
    // even if it isn't currently playing: that's the whole point of a
    // preference, not just a tie-breaker. Empty string means no preference
    // at all: skip straight to whichever player is actually playing.
    property string prefer: "org.mpris.MediaPlayer2.spotify"

    // playerctld is filtered out: it's a proxy for the other players and
    // would show up as a duplicate.
    readonly property var current: {
        const all = Mpris.players.values.filter(
            p => p.dbusName !== "org.mpris.MediaPlayer2.playerctld");
        if (all.length === 0)
            return null;
        const preferred = root.prefer
            ? all.find(p => p.dbusName.startsWith(root.prefer)) : undefined;
        return preferred
            ?? all.find(p => p.isPlaying)
            ?? all[0];
    }

    readonly property bool available: current !== null
    readonly property bool playing:   current ? current.isPlaying : false
    readonly property string artUrl:  current ? current.trackArtUrl : ""
    readonly property string title:   current ? current.trackTitle : ""
    readonly property string artist:  current ? current.trackArtist : ""

    readonly property string album: current ? current.trackAlbum : ""

    readonly property bool canPrev:   current ? current.canGoPrevious : false
    readonly property bool canNext:   current ? current.canGoNext : false
    readonly property bool canToggle: current ? current.canTogglePlaying : false

    // Playback position. MPRIS doesn't push updates as it advances, it has
    // to be polled, and only every so often. Polling every 500ms made the
    // progress dot jump ~2px at a time. So between polls the position
    // advances on a local clock, and MPRIS is only used to correct it.
    property real position: 0
    readonly property real duration: current && current.lengthSupported ? current.length : 0
    readonly property real progress: duration > 0 ? Math.min(1, position / duration) : 0

    readonly property Timer positionPoll: Timer {
        running: root.playing
        interval: 2000
        repeat: true
        onTriggered: root.syncPosition()
    }

    // 100ms is enough: on a three-minute song the progress dot moves half a
    // pixel per tick. Any faster just adds repaints on top of the ones the
    // wave animation already needs.
    readonly property Timer positionTick: Timer {
        running: root.playing
        interval: 100
        repeat: true

        property double last: 0
        onRunningChanged: last = Date.now()

        onTriggered: {
            const now = Date.now();
            root.position += (now - last) / 1000;
            last = now;
        }
    }

    onPlayingChanged: syncPosition()
    onCurrentChanged: syncPosition()

    function syncPosition() {
        position = current && current.positionSupported ? current.position : 0;
    }

    readonly property bool hasVolume: current ? current.volumeSupported : false
    readonly property real volume:    current && current.volumeSupported ? current.volume : 0

    function previous() { if (canPrev) current.previous(); }
    function next()     { if (canNext) current.next(); }
    function toggle()   { if (canToggle) current.togglePlaying(); }

    // Seconds to m:ss. Returns an empty string when there's no data, so the
    // UI never shows a misleading "0:00" for a value that's actually unknown.
    function formatClock(seconds) {
        if (!(seconds >= 0))
            return "";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function nudgeVolume(delta) {
        if (!hasVolume)
            return;
        current.volume = Math.max(0, Math.min(1, current.volume + delta));
    }
}
