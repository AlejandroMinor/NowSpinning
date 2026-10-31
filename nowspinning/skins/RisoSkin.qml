// Skin: the cover as a risograph print.
//
// The cover in halftone dots of two or three riso inks (fluorescent pink,
// blue, and yellow), each ink on its own screen angle and each a little
// out of register, on cream paper, with the title and the artist printed
// under it in the same inks. Each new track goes through the machine
// again: one ink at a time, yellow, pink, then blue, and lands out of
// register its own way.
//
// Sways while playing and turns toward the pointer, like the other flat
// skins. The back, for the track info, is the sheet flooded in blue ink.
//
// Options: risoInks (3, or 2: pink and blue only), lightMotion and
// lightTilt.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title` and `artist`.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property string artist: ""
    property bool blankLabel: false
    property int risoInks: 3          // 3: pink, blue and yellow; 2: pink and blue
    property bool lightMotion: true   // swaying on its own
    property bool lightTilt: true     // turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // The sheet, and the square printed on it.
    readonly property real w: Math.round(size * 0.94)
    readonly property real h: Math.round(w * 1.17)
    readonly property real margin: w * 0.07
    readonly property real picture: w - 2 * margin

    implicitWidth: w
    implicitHeight: h

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    readonly property color paper: "#f4efe4"
    // The inks, in the order they go through the machine, each with its
    // screen angle. Pink and blue alone still read as the cover.
    readonly property var inks: [
        { name: "yellow", color: "#ffe800", angle: 0 },
        { name: "pink", color: "#ff48b0", angle: 75 },
        { name: "blue", color: "#0078bf", angle: 15 }
    ]
    // Dots across the picture: about four pixels each, whatever the size.
    readonly property int cells: Math.max(32, Math.round(picture / 3.8))

    function hash(s) {
        let n = 7;
        for (let i = 0; i < s.length; i++)
            n = (n * 31 + s.charCodeAt(i)) % 1000003;
        return n;
    }
    // How far each ink lands from where it should, per track: the same
    // track always prints the same way.
    readonly property var offsets: {
        const seed = hash(artUrl + title);
        const out = {};
        for (let i = 0; i < inks.length; i++) {
            const a = ((seed >> (i * 3)) % 360) * Math.PI / 180;
            const d = (0.5 + ((seed >> (i * 5)) % 100) / 100) * size * 0.008;
            out[inks[i].name] = { x: Math.cos(a) * d, y: Math.sin(a) * d };
        }
        return out;
    }

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
        columns: 96
        onSampled: {
            skin.screen();
            if (!skin.blankLabel)
                skin.runPress();
        }
    }

    // How many inks are down, 0..3: a new print comes out one ink at a
    // time (two inks start at pink).
    property int passes: 3
    onPassesChanged: sheet.requestPaint()
    function runPress() {
        passes = risoInks < 3 ? 1 : 0;
        printing.restart();
    }
    Timer {
        id: printing
        interval: 260
        repeat: true
        onTriggered: {
            skin.passes += 1;
            if (skin.passes >= 3)
                stop();
        }
    }

    // How much of an ink the cover's colour takes, 0..1, at a point of the
    // picture (0..1 each way), read between the samples.
    function density(ink, u, v) {
        const px = cover.pixels, n = cover.columns;
        const fx = Math.max(0, Math.min(n - 1.001, u * n - 0.5));
        const fy = Math.max(0, Math.min(n - 1.001, v * n - 0.5));
        const x0 = Math.floor(fx), y0 = Math.floor(fy);
        const tx = fx - x0, ty = fy - y0;
        const at = (x, y) => {
            const o = (y * n + x) * 3;
            const r = px[o] / 255, g = px[o + 1] / 255, b = px[o + 2] / 255;
            // Black is every ink at once; with only two, they share it.
            const k = 1 - Math.max(r, g, b);
            // Less yellow in the shadows, or they go green.
            if (ink === "yellow")
                return (1 - b) * (1 - k * 0.6);
            if (ink === "pink")
                return Math.min(1, 1 - g + (skin.risoInks < 3 ? k * 0.35 : 0));
            return Math.min(1, 1 - r + (skin.risoInks < 3 ? k * 0.5 : 0));
        };
        const top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx;
        const bottom = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx;
        // Lighter than the cover: the paper shows through the highlights,
        // and three inks on top of each other don't go to mud.
        const d = Math.max(0, (top * (1 - ty) + bottom * ty - 0.1) / 0.9);
        return Math.pow(d, 1.25);
    }

    // Each ink's dots, x, y and radius in a row, worked out once per cover
    // (and size, and number of inks) and only drawn after that.
    property var dots: ({})
    function screen() {
        const out = {};
        if (cover.pixels.length === cover.columns * cover.rows * 3) {
            const p = picture, cell = p / cells;
            const reach = Math.ceil(cells * 0.75) + 1;
            for (const ink of inks) {
                const a = ink.angle * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a);
                const list = [];
                for (let gy = -reach; gy <= reach; gy++) {
                    for (let gx = -reach; gx <= reach; gx++) {
                        // The ink's grid, turned by its angle about the
                        // picture's middle.
                        const lx = (gx + 0.5) * cell, ly = (gy + 0.5) * cell;
                        const x = p / 2 + lx * ca - ly * sa, y = p / 2 + lx * sa + ly * ca;
                        if (x < 0 || y < 0 || x > p || y > p)
                            continue;
                        const d = density(ink.name, x / p, y / p);
                        if (d >= 0.04)
                            list.push(x, y, cell * 0.62 * Math.sqrt(d));
                    }
                }
                out[ink.name] = list;
            }
        }
        dots = out;
        sheet.requestPaint();
    }
    onRisoInksChanged: screen()
    onPictureChanged: screen()

    Canvas {
        id: sheet
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            const W = width, H = height, m = skin.margin, p = skin.picture;
            ctx.reset();
            ctx.fillStyle = skin.paper;
            ctx.fillRect(0, 0, W, H);

            if (skin.blankLabel) {
                ctx.globalCompositeOperation = "qt-multiply";
                ctx.fillStyle = "#0078bf";
                ctx.globalAlpha = 0.92;
                ctx.fillRect(m * 0.5, m * 0.5, W - m, H - m);
                return;
            }

            ctx.globalCompositeOperation = "qt-multiply";
            ctx.globalAlpha = 0.9;
            // Yellow goes first, then pink, then blue.
            for (let pass = 0; pass < skin.passes; pass++) {
                const ink = skin.inks[pass];
                const list = skin.dots[ink.name];
                if (!list || (ink.name === "yellow" && skin.risoInks < 3))
                    continue;
                const off = skin.offsets[ink.name];
                ctx.fillStyle = ink.color;
                ctx.beginPath();
                for (let i = 0; i < list.length; i += 3) {
                    const cx = m + list[i] + off.x, cy = m + list[i + 1] + off.y, r = list[i + 2];
                    ctx.moveTo(cx + r, cy);
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                }
                ctx.fill();
            }

            // The type, each line in one ink, out of register with it.
            const textY = m + p + (H - m - p) * 0.42;
            if (skin.passes > 1) {
                const off = skin.offsets.pink;
                ctx.fillStyle = "#ff48b0";
                ctx.font = "900 " + Math.round(skin.w * 0.075) + "px sans-serif";
                ctx.textBaseline = "middle";
                ctx.fillText(fit(ctx, skin.title.toUpperCase(), p), m + off.x, textY + off.y);
            }
            if (skin.passes > 2) {
                const off = skin.offsets.blue;
                ctx.fillStyle = "#0078bf";
                ctx.font = "600 " + Math.round(skin.w * 0.05) + "px sans-serif";
                ctx.textBaseline = "middle";
                ctx.fillText(fit(ctx, skin.artist, p), m + off.x, textY + skin.w * 0.075 + off.y);
            }
        }

        // Shortened with an ellipsis until it fits.
        function fit(ctx, text, room) {
            if (ctx.measureText(text).width <= room)
                return text;
            let t = text;
            while (t.length > 1 && ctx.measureText(t + "…").width > room)
                t = t.slice(0, -1);
            return t + "…";
        }
    }

    onTitleChanged: sheet.requestPaint()
    onArtistChanged: sheet.requestPaint()
    onBlankLabelChanged: sheet.requestPaint()
    onWidthChanged: sheet.requestPaint()

    // Paper grain: a few specks of the paper's own fibre, drawn once.
    Canvas {
        anchors.fill: parent
        opacity: 0.5
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            let s = 12345;
            const rand = () => (s = (s * 16807) % 2147483647) / 2147483647;
            for (let i = 0; i < width * height / 60; i++) {
                ctx.fillStyle = rand() < 0.5 ? "rgba(120, 100, 70, 0.18)" : "rgba(255, 255, 255, 0.5)";
                ctx.fillRect(rand() * width, rand() * height, 1, 1);
            }
        }
    }
}
