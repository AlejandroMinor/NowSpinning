// How loud the music is right now, band by band, read from cava.
//
// MPRIS only gives position and duration, never the audio itself, so the
// progress wave used to be a plain sine. cava listens to what's actually
// playing (through PipeWire or Pulse, whichever it finds) and prints one
// line per frame: a level per frequency band, lows first. This turns those
// lines into `levels`, 0..1 each.
//
// cava only runs while `active`; it costs a little CPU, so the window
// keeps it off while nothing is playing or the wave isn't on screen. If
// cava isn't installed, or hears nothing, `levels` stays empty and the
// wave falls back to its plain sine.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: audio

    property bool active: false
    property int bands: 16

    property var levels: []
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

    // Its own config, written next to the session's runtime files on each
    // start: raw numbers on stdout, one line per frame, 0..1000.
    readonly property string configPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/nowspinning-cava.conf"

    Process {
        id: cava
        running: audio.active
        command: ["sh", "-c",
            "printf '[general]\\nbars = %d\\nframerate = 30\\n"
            + "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\n"
            + "ascii_max_range = 1000\\nchannels = mono\\n' \"$1\" > \"$2\" && exec cava -p \"$2\"",
            "nowspinning-cava", String(audio.bands), audio.configPath]

        stdout: SplitParser {
            onRead: line => {
                const out = [];
                for (const part of line.split(";")) {
                    if (part !== "")
                        out.push(Math.min(1, Number(part) / 1000));
                }
                if (out.length > 0)
                    audio.levels = out;
            }
        }

        onRunningChanged: if (!running) audio.levels = []
    }
}
