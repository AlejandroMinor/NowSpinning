// Skin: the cover on a four-tone LCD.
//
// The cover dithered down to four shades of green (or grey, or amber) on a
// coarse dot-matrix screen set in a grey plastic bezel. The dots stand a
// little off the screen's back and cast their shadow on it, the way an old
// reflective LCD does, and they are slow: on a new track the last cover
// lingers as a ghost while the new one darkens in. The power light is on
// while playing; paused, a pause sign shows in the corner of the screen.
//
// Sways while playing and turns toward the pointer, a glare sliding across
// the screen's plastic window. The back, for the track info, is the screen
// switched off.
//
// Options: lcdColor ("green", "gray" or "amber"), lightMotion and
// lightTilt.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`.
import QtQuick
import QtQuick.Effects
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property bool blankLabel: false
    property string lcdColor: "green"
    property bool lightMotion: true   // swaying on its own
    property bool lightTilt: true     // turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    implicitWidth: size
    implicitHeight: Math.round(size * 1.13)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Darkest to lightest; the lightest is the screen itself.
    readonly property var palettes: ({
        green: ["#0f380f", "#306230", "#6b8f17", "#9bbc0f"],
        gray: ["#24241f", "#55554b", "#9a9a8c", "#bdbdae"],
        amber: ["#3a1500", "#8a3d00", "#e08a1e", "#f6b44a"]
    })
    readonly property var tones: palettes[lcdColor] ?? palettes.green

    readonly property int dots: 48    // the screen, a side
    readonly property real bezel: size * 0.085
    readonly property real screenSize: size - 2 * bezel
    readonly property real cell: screenSize / dots

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: skin.lightMotion
        follow: skin.lightTilt
        area: skin.faceRect
    }

    transform: [
        Tilt { target: skin; amount: light.lightX; degrees: 8 },
        Tilt { target: skin; amount: light.lightY; degrees: 8; vertical: true }
    ]

    CoverPixels {
        id: cover
        source: skin.blankLabel ? "" : skin.artUrl
        columns: skin.dots
        onSampled: skin.dither()
    }

    // Each dot's shade, 0 (darkest) to 3 (off), row by row: the cover's
    // brightness stretched over the four, then an ordered (Bayer) dither so
    // the steps between them become patterns of dots.
    property var frame: []
    property var ghost: []
    readonly property var bayer: [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    function dither() {
        const px = cover.pixels, n = dots;
        const out = [];
        if (px.length === n * n * 3) {
            const light = [];
            for (let i = 0; i < n * n; i++)
                light.push((0.299 * px[i * 3] + 0.587 * px[i * 3 + 1] + 0.114 * px[i * 3 + 2]) / 255);
            // Stretched between the darkest and lightest few percent, so a
            // dim cover still uses all four shades.
            const sorted = light.slice().sort((a, b) => a - b);
            const lo = sorted[Math.floor(sorted.length * 0.03)];
            const hi = sorted[Math.floor(sorted.length * 0.97)];
            const span = Math.max(0.1, hi - lo);
            for (let y = 0; y < n; y++) {
                for (let x = 0; x < n; x++) {
                    const l = Math.max(0, Math.min(1, (light[y * n + x] - lo) / span));
                    const t = (bayer[(y % 4) * 4 + x % 4] + 0.5) / 16 - 0.5;
                    out.push(Math.max(0, Math.min(3, Math.round(l * 3 + t))));
                }
            }
        }
        ghost = frame;
        frame = out;
        lit.requestPaint();
        ghostDots.requestPaint();
        if (!blankLabel && ghost.length > 0)
            settling.restart();
    }

    // The bezel.
    Rectangle {
        anchors.fill: parent
        radius: skin.size * 0.07
        gradient: Gradient {
            GradientStop { position: 0; color: "#8d8f96" }
            GradientStop { position: 1; color: "#6c6e75" }
        }
        border { width: Math.max(1, skin.size * 0.006); color: Qt.rgba(1, 1, 1, 0.18) }
    }

    // The power light, and the title moulded under the screen.
    Rectangle {
        x: skin.bezel * 0.36
        y: skin.bezel + skin.screenSize * 0.3
        width: skin.bezel * 0.36
        height: width
        radius: width / 2
        color: skin.playing && !skin.blankLabel ? "#ff3b30" : "#4a2a2a"
        layer.enabled: skin.playing && !skin.blankLabel
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#ff3b30"
            shadowBlur: 0.6
            shadowOpacity: 0.9
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
    Text {
        x: skin.bezel
        width: skin.screenSize
        y: skin.bezel + skin.screenSize + (skin.height - skin.bezel - skin.screenSize - height) / 2
        visible: !skin.blankLabel
        text: skin.title
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        color: "#3c3e44"
        style: Text.Raised
        styleColor: Qt.rgba(1, 1, 1, 0.25)
        font { family: "sans-serif"; pixelSize: Math.max(6, Math.round(skin.size * 0.06)); italic: true; weight: Font.Bold }
    }

    // The screen.
    Rectangle {
        id: screen
        x: skin.bezel
        y: skin.bezel
        width: skin.screenSize
        height: skin.screenSize
        radius: skin.size * 0.012
        color: skin.blankLabel ? "#2a2f26" : skin.tones[3]
        clip: true

        // The last cover, fading off the slow crystals.
        Canvas {
            id: ghostDots
            anchors.fill: parent
            opacity: 0
            onPaint: skin.paintDots(getContext("2d"), skin.ghost)
        }
        // The dots stand off the screen's back: they cast a shadow on it.
        Canvas {
            id: lit
            anchors.fill: parent
            onPaint: skin.paintDots(getContext("2d"), skin.frame)
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.tones[0]
                shadowOpacity: 0.28
                shadowBlur: 0.08
                shadowHorizontalOffset: skin.cell * 0.45
                shadowVerticalOffset: skin.cell * 0.6
            }
        }
        ParallelAnimation {
            id: settling
            NumberAnimation { target: ghostDots; property: "opacity"; from: 0.7; to: 0; duration: 1100; easing.type: Easing.OutQuad }
            NumberAnimation { target: lit; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.InQuad }
        }

        // Paused: the sign in the corner, in dots of the darkest shade.
        Row {
            anchors { right: parent.right; top: parent.top; margins: skin.cell * 2 }
            spacing: skin.cell
            visible: !skin.playing && !skin.blankLabel && skin.frame.length > 0
            Repeater {
                model: 2
                Rectangle {
                    width: skin.cell * 2
                    height: skin.cell * 6
                    color: skin.tones[0]
                    border { width: Math.max(1, skin.cell * 0.5); color: skin.tones[3] }
                }
            }
        }

        // The plastic window over the screen, catching the light.
        Glint {
            lightX: light.lightX
            strength: 0.16
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: parent.radius
            border { width: Math.max(1, skin.size * 0.008); color: Qt.rgba(0, 0, 0, 0.35) }
        }
    }

    // The dots of one frame, each a square a little smaller than its cell:
    // the gaps between them are the screen showing through.
    function paintDots(ctx, shades) {
        ctx.reset();
        if (blankLabel || shades.length !== dots * dots)
            return;
        const gap = cell > 2.5 ? cell * 0.1 : 0;
        for (let shade = 0; shade < 3; shade++) {
            ctx.fillStyle = tones[shade];
            ctx.beginPath();
            for (let i = 0; i < shades.length; i++) {
                if (shades[i] === shade)
                    ctx.rect((i % dots) * cell, Math.floor(i / dots) * cell, cell - gap, cell - gap);
            }
            ctx.fill();
        }
    }
    onTonesChanged: {
        lit.requestPaint();
        ghostDots.requestPaint();
    }
    onSizeChanged: lit.requestPaint()
    onBlankLabelChanged: lit.requestPaint()
}
