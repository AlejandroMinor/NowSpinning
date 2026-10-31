// Skin: the cover, datamoshed.
//
// A video whose keyframe got lost: on a new track the old cover doesn't
// cut away, its pixels get dragged along by the new one's motion, in
// blocks, with the new cover's edges already printed over them, until
// block by block the new cover comes through clean. Under the pointer the
// pixels drag along with it, and heal a moment after it stops. While
// playing, a few rows of blocks slip now and then, or with the beat when
// `audioLevel` comes in.
//
// Drawn as a small video frame (96 x 96, in 8 x 8 blocks) and scaled up.
// It only works while something moves: once every block is clean, nothing
// runs. A readout under the screen says which kind of frame is showing.
//
// The back, for the track info, is the screen with no signal.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title` and `audioLevel`.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property bool blankLabel: false
    property bool lightMotion: true   // the rows slipping now and then
    property bool lightTilt: true     // the pixels dragging with the pointer
    // How loud the low end is right now, 0..1, while `audioReact` is on
    // (AudioLevels.qml); 0 otherwise, and the skin keeps its own glitches.
    property real audioLevel: 0

    readonly property bool supportsFullArt: false
    property bool artFull: false

    implicitWidth: size
    implicitHeight: Math.round(size * 1.1)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false
    // It glows a little instead.
    readonly property bool ownShadow: true

    readonly property real pad: Math.round(size * 0.035)
    readonly property real side: size - 2 * pad

    // The frame, and its blocks.
    readonly property int n: 96
    readonly property int block: 8
    readonly property int blocks: n / block

    readonly property color cyan: "#29f0ff"
    readonly property color magenta: "#ff2bd6"

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
        onFollowingChanged: if (following) skin.wake()
    }

    transform: [
        Tilt { target: skin; amount: light.lightX; degrees: 5 },
        Tilt { target: skin; amount: light.lightY; degrees: 5; vertical: true }
    ]

    CoverPixels {
        id: cover
        source: skin.blankLabel ? "" : skin.artUrl
        columns: skin.n
        onSampled: skin.arrive()
    }

    // What's on screen and what should be, r, g, b per pixel; and per
    // block its motion (vx, vy, in pixels a frame), whether it adds the new
    // cover's difference on top (a P-frame of the new track, read against
    // the old one's pixels), and when it heals back to clean.
    property var st: ({ cur: null, target: null, vx: [], vy: [], residual: [], healAt: [],
                        dirty: [], pointer: null, lastBeat: 0 })
    property int frameNo: 0
    property bool moshing: false

    function rand(lo, hi) {
        return lo + Math.random() * (hi - lo);
    }

    // A new cover. The first one (or one with nothing before it) just
    // shows; after that it's moshed in.
    function arrive() {
        const px = cover.pixels, s = st, count = blocks * blocks;
        if (px.length !== n * n * 3) {
            s.cur = null;
            s.target = null;
            stop();
            picture.requestPaint();
            return;
        }
        const target = new Uint8ClampedArray(px);
        s.vx = new Array(count).fill(0);
        s.vy = new Array(count).fill(0);
        s.residual = new Array(count).fill(false);
        s.healAt = new Array(count).fill(0);
        s.dirty = new Array(count).fill(false);
        if (!s.cur || !s.target) {
            s.cur = new Uint8ClampedArray(target);
            s.target = target;
            picture.requestPaint();
            return;
        }
        s.target = target;
        // One motion for the whole frame, its own per track: a drift one
        // way, a swirl, or a melt down, with some noise per block.
        const now = Date.now(), kind = Math.floor(Math.random() * 3);
        const angle = Math.random() * 2 * Math.PI;
        const turn = Math.random() < 0.5 ? 1 : -1;
        for (let by = 0; by < blocks; by++) {
            for (let bx = 0; bx < blocks; bx++) {
                const b = by * blocks + bx;
                let x, y;
                if (kind === 0) {
                    x = Math.cos(angle) * 1.6;
                    y = Math.sin(angle) * 1.6;
                } else if (kind === 1) {
                    const cx = bx - blocks / 2 + 0.5, cy = by - blocks / 2 + 0.5;
                    const d = Math.max(1, Math.hypot(cx, cy));
                    x = -cy / d * 2 * turn;
                    y = cx / d * 2 * turn;
                } else {
                    x = 0;
                    y = 1 + (bx % 3);
                }
                s.vx[b] = Math.round(x + rand(-0.7, 0.7));
                s.vy[b] = Math.round(y + rand(-0.7, 0.7));
                s.residual[b] = true;
                s.dirty[b] = true;
                s.healAt[b] = now + rand(500, 2100);
            }
        }
        wake();
    }

    // A few rows of blocks slipping sideways for a moment.
    function glitch() {
        const s = st;
        if (!s.cur || !s.target || blankLabel)
            return;
        const now = Date.now();
        const rows = 1 + Math.floor(Math.random() * 3);
        for (let r = 0; r < rows; r++) {
            const by = Math.floor(Math.random() * blocks);
            const shift = (Math.random() < 0.5 ? -1 : 1) * (2 + Math.floor(Math.random() * 3));
            for (let bx = 0; bx < blocks; bx++) {
                const b = by * blocks + bx;
                s.vx[b] = shift;
                s.vy[b] = 0;
                s.residual[b] = false;
                s.dirty[b] = true;
                s.healAt[b] = now + rand(250, 650);
            }
        }
        wake();
    }
    onAudioLevelChanged: {
        if (audioLevel > 0.88 && playing && Date.now() - st.lastBeat > 500) {
            st.lastBeat = Date.now();
            glitch();
        }
    }
    Timer {
        interval: 4600
        repeat: true
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        // The beat takes over while it's coming in.
        onTriggered: if (Date.now() - skin.st.lastBeat > 3000) skin.glitch()
    }

    function wake() {
        moshing = true;
        tick.start();
    }
    function stop() {
        tick.stop();
        moshing = false;
        st.pointer = null;
    }
    Timer {
        id: tick
        interval: 40
        repeat: true
        onTriggered: skin.step()
    }

    // One frame: drag the pointer's blocks, move every block by its motion,
    // heal the ones whose time has come.
    function step() {
        const s = st, now = Date.now();
        if (!s.cur || !s.target) {
            stop();
            return;
        }
        if (light.following) {
            const p = Qt.point((light.pointer.x - pad) / side * n, (light.pointer.y - pad) / side * n);
            if (s.pointer) {
                const dx = p.x - s.pointer.x, dy = p.y - s.pointer.y;
                if (dx * dx + dy * dy > 0.01) {
                    for (let by = 0; by < blocks; by++) {
                        for (let bx = 0; bx < blocks; bx++) {
                            const cx = (bx + 0.5) * block, cy = (by + 0.5) * block;
                            const fall = Math.exp(-((cx - p.x) ** 2 + (cy - p.y) ** 2) / (2 * (block * 1.8) ** 2));
                            if (fall < 0.15)
                                continue;
                            const b = by * blocks + bx;
                            s.vx[b] = Math.max(-5, Math.min(5, Math.round(dx * fall)));
                            s.vy[b] = Math.max(-5, Math.min(5, Math.round(dy * fall)));
                            s.residual[b] = false;
                            s.dirty[b] = true;
                            s.healAt[b] = now + rand(900, 1700);
                        }
                    }
                }
            }
            s.pointer = p;
        } else {
            s.pointer = null;
        }

        // Nothing to move: wait for the pointer, or stop.
        if (!s.dirty.some(d => d)) {
            moshing = false;
            if (!light.following)
                stop();
            return;
        }
        moshing = true;

        const cur = s.cur, target = s.target, next = new Uint8ClampedArray(cur);
        for (let b = 0; b < blocks * blocks; b++) {
            if (!s.dirty[b])
                continue;
            const x0 = (b % blocks) * block, y0 = Math.floor(b / blocks) * block;
            if (now >= s.healAt[b]) {
                // A keyframe for this block: clean again.
                for (let y = y0; y < y0 + block; y++) {
                    const i = (y * n + x0) * 3;
                    for (let k = 0; k < block * 3; k++)
                        next[i + k] = target[i + k];
                }
                s.dirty[b] = false;
                s.vx[b] = 0;
                s.vy[b] = 0;
                continue;
            }
            const vx = s.vx[b], vy = s.vy[b], add = s.residual[b];
            if (vx === 0 && vy === 0)
                continue;
            for (let y = y0; y < y0 + block; y++) {
                const sy = Math.min(n - 1, Math.max(0, y - vy));
                for (let x = x0; x < x0 + block; x++) {
                    const sx = Math.min(n - 1, Math.max(0, x - vx));
                    const i = (y * n + x) * 3, j = (sy * n + sx) * 3;
                    for (let c = 0; c < 3; c++)
                        next[i + c] = add ? cur[j + c] + target[i + c] - target[j + c] : cur[j + c];
                }
            }
            // The pointer's drag dies down once it stops.
            if (!add) {
                s.vx[b] = Math.trunc(vx * 0.7);
                s.vy[b] = Math.trunc(vy * 0.7);
            }
        }
        s.cur = next;
        frameNo += 1;
        picture.requestPaint();
    }

    // The set: a dark frame, the screen in it, a readout under it.
    Rectangle {
        anchors.fill: parent
        radius: skin.size * 0.03
        color: "#07080c"
        border { width: Math.max(1, skin.size * 0.005); color: Qt.rgba(1, 1, 1, 0.08) }
    }
    // While moshing, the screen's edge splits into cyan and magenta.
    Repeater {
        model: [{ c: skin.cyan, d: -1 }, { c: skin.magenta, d: 1 }]
        Rectangle {
            required property var modelData
            x: skin.pad + modelData.d * skin.size * 0.008
            y: skin.pad - modelData.d * skin.size * 0.004
            width: skin.side
            height: skin.side
            color: "transparent"
            border { width: Math.max(1, skin.size * 0.006); color: modelData.c }
            opacity: skin.moshing ? 0.85 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }
    }
    Rectangle {
        x: skin.pad
        y: skin.pad
        width: skin.side
        height: skin.side
        color: "black"
        clip: true

        Canvas {
            id: picture
            // One frame's worth of pixels, kept: a new one each frame is
            // 36k values of garbage 25 times a second, and the collector
            // chasing it costs far more than the drawing.
            property var img: null
            width: skin.n
            height: skin.n
            scale: skin.side / skin.n
            transformOrigin: Item.TopLeft
            onPaint: {
                const ctx = getContext("2d");
                const cur = skin.st.cur;
                if (!cur || skin.blankLabel) {
                    ctx.fillStyle = "black";
                    ctx.fillRect(0, 0, width, height);
                    return;
                }
                if (!img)
                    img = ctx.createImageData(width, height);
                const d = img.data;
                for (let i = 0, j = 0; i < cur.length; i += 3, j += 4) {
                    d[j] = cur[i];
                    d[j + 1] = cur[i + 1];
                    d[j + 2] = cur[i + 2];
                    d[j + 3] = 255;
                }
                // With its dirty rect spelled out: without it, Qt's puts nothing.
                ctx.putImageData(img, 0, 0, 0, 0, width, height);
            }
        }

        Text {
            anchors.centerIn: parent
            visible: skin.blankLabel
            text: "NO SIGNAL"
            color: Qt.rgba(1, 1, 1, 0.25)
            font { family: "monospace"; pixelSize: Math.round(skin.size * 0.07); weight: Font.Bold; letterSpacing: skin.size * 0.01 }
        }
    }
    onBlankLabelChanged: picture.requestPaint()

    // The readout: which kind of frame, and the title.
    Row {
        x: skin.pad
        y: skin.pad + skin.side + (skin.height - skin.pad - skin.side - height) / 2
        width: skin.side
        spacing: skin.size * 0.03
        visible: !skin.blankLabel
        Text {
            id: kind
            text: skin.moshing ? "P-FRAME " + String(skin.frameNo % 10000).padStart(4, "0") : "I-FRAME"
            color: skin.moshing ? skin.magenta : skin.cyan
            font { family: "monospace"; pixelSize: Math.max(5, Math.round(skin.size * 0.045)); weight: Font.Bold }
        }
        Text {
            width: skin.side - kind.width - parent.spacing
            text: skin.title
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            color: Qt.rgba(1, 1, 1, 0.7)
            font { family: "monospace"; pixelSize: Math.max(5, Math.round(skin.size * 0.045)) }
        }
    }
}
