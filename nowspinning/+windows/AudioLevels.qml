// Windows' take on ../AudioLevels.qml: the same levels, band by band, lows
// first, 0..1, read from what the default output is playing (WASAPI
// loopback, in nowspinning.exe) instead of from cava, so there's nothing to
// install. Only listens while `active`; with no output to listen to,
// `levels` stays empty and the wave falls back to its plain sine.
// Picked over the Linux one by nowspinning.exe; Quickshell never reads
// this folder.
import QtQuick
import NowSpinning.Host

Item {
    id: audio

    property bool active: false
    property int bands: 16

    readonly property var levels: capture.levels
    readonly property bool live: levels.length > 0
    // The low end, the first few bands: what a skin pulses with.
    readonly property real bass: {
        // Read once: looking up a var property from JS is far from free.
        const L = levels, n = Math.min(3, L.length);
        let sum = 0;
        for (let i = 0; i < n; i++)
            sum += L[i];
        return n > 0 ? sum / n : 0;
    }

    AudioCapture {
        id: capture
        active: audio.active
        bands: audio.bands
    }
}
