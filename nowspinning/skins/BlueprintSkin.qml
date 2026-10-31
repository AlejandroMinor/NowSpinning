// Skin: the cover as a blueprint.
//
// The cover drawn in white lines on blueprint blue: its contours, the dark
// parts hatched (cross-hatched where they're darkest), centre lines
// through it, on a gridded sheet with a drawing border. A dimension line
// over it gives the track's length, and a title block under it the title,
// the artist and a drawing number. Each new track is plotted again, the
// pen sweeping down the sheet. A DETAIL circle sits on the drawing; under
// the pointer it follows it. Paused, the sheet is stamped ON HOLD.
//
// Sways while playing and turns toward the pointer, like the other flat
// skins. The back, for the track info, is the empty sheet.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist` and `duration`.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property string artist: ""
    property real duration: 0
    property bool blankLabel: false
    property bool lightMotion: true   // swaying on its own
    property bool lightTilt: true     // turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color paper: "#1d4f91"
    readonly property color ink: "#f2f6ff"

    readonly property real w: Math.round(size * 0.96)
    readonly property real h: Math.round(w * 1.22)
    readonly property real margin: w * 0.06
    // The drawing, a square under the dimension line.
    readonly property real picture: w * 0.78
    readonly property real px: (w - picture) / 2
    readonly property real py: margin + w * 0.09

    implicitWidth: w
    implicitHeight: h

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    readonly property real line: Math.max(0.7, size * 0.0045)
    readonly property real textSize: Math.max(5, size * 0.042)

    function clock(seconds) {
        const s = Math.max(0, Math.round(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function hash(s, m) {
        let n = 0;
        for (let i = 0; i < s.length; i++)
            n = (n * 31 + s.charCodeAt(i)) % m;
        return n;
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
        Tilt { target: skin; amount: light.lightX; degrees: 7 },
        Tilt { target: skin; amount: light.lightY; degrees: 7; vertical: true }
    ]

    CoverPixels {
        id: cover
        source: skin.blankLabel ? "" : skin.artUrl
        columns: 96
        onSampled: skin.trace()
    }

    // The cover's brightness, smoothed a little so the contours come out as
    // lines and not as noise, then stretched to the cover's own range: a
    // dim or washed-out cover still gets its full set of tones.
    property var levels: []
    function trace() {
        const px = cover.pixels, n = cover.columns;
        const out = [];
        if (px.length === n * n * 3) {
            const raw = [];
            for (let i = 0; i < n * n; i++)
                raw.push((0.299 * px[i * 3] + 0.587 * px[i * 3 + 1] + 0.114 * px[i * 3 + 2]) / 255);
            // A light blur, the centre weighed most, to keep the detail.
            for (let y = 0; y < n; y++) {
                for (let x = 0; x < n; x++) {
                    let sum = 0, k = 0;
                    for (let dy = -1; dy <= 1; dy++) {
                        for (let dx = -1; dx <= 1; dx++) {
                            const xx = x + dx, yy = y + dy;
                            if (xx >= 0 && yy >= 0 && xx < n && yy < n) {
                                const wgt = dx === 0 && dy === 0 ? 4 : dx === 0 || dy === 0 ? 2 : 1;
                                sum += raw[yy * n + xx] * wgt;
                                k += wgt;
                            }
                        }
                    }
                    out.push(sum / k);
                }
            }
            const sorted = out.slice().sort((a, b) => a - b);
            const lo = sorted[Math.floor(sorted.length * 0.02)];
            const hi = sorted[Math.floor(sorted.length * 0.98)];
            const span = Math.max(0.05, hi - lo);
            for (let i = 0; i < out.length; i++)
                out[i] = Math.min(1, Math.max(0, (out[i] - lo) / span));
        }
        levels = out;
        drawing.requestPaint();
        if (!blankLabel && out.length > 0)
            plotting.restart();
    }

    // The sheet: blue paper, its grid and the drawing border.
    Rectangle {
        anchors.fill: parent
        radius: skin.size * 0.01
        color: skin.paper
    }
    Canvas {
        id: sheet
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const step = Math.max(1, skin.w / 40);
            ctx.lineWidth = 1;
            for (let i = 0; i * step <= width; i++) {
                ctx.strokeStyle = i % 5 === 0 ? "rgba(200, 220, 255, 0.16)" : "rgba(200, 220, 255, 0.07)";
                ctx.beginPath();
                ctx.moveTo(i * step, 0);
                ctx.lineTo(i * step, height);
                ctx.stroke();
            }
            for (let i = 0; i * step <= height; i++) {
                ctx.strokeStyle = i % 5 === 0 ? "rgba(200, 220, 255, 0.16)" : "rgba(200, 220, 255, 0.07)";
                ctx.beginPath();
                ctx.moveTo(0, i * step);
                ctx.lineTo(width, i * step);
                ctx.stroke();
            }
            const m = skin.margin * 0.55;
            ctx.strokeStyle = "rgba(242, 246, 255, 0.85)";
            ctx.lineWidth = skin.line * 1.6;
            ctx.strokeRect(m, m, width - 2 * m, height - 2 * m);
            ctx.lineWidth = skin.line * 0.6;
            ctx.strokeRect(m + skin.line * 3, m + skin.line * 3, width - 2 * m - skin.line * 6, height - 2 * m - skin.line * 6);
        }
    }

    // The drawing, plotted down the sheet on each new track.
    property real plotted: 1
    NumberAnimation {
        id: plotting
        target: skin
        property: "plotted"
        from: 0
        to: 1
        duration: 1400
        easing.type: Easing.InOutSine
    }
    Item {
        id: reveal
        x: 0
        y: 0
        width: skin.w
        height: skin.py + skin.picture * skin.plotted + skin.line
        clip: true

        Canvas {
            id: drawing
            width: skin.w
            height: skin.h
            onPaint: skin.paintDrawing(getContext("2d"))
        }
    }
    // The pen, while it plots.
    Rectangle {
        visible: skin.plotted > 0 && skin.plotted < 1
        x: skin.px - skin.w * 0.02
        width: skin.picture + skin.w * 0.04
        y: skin.py + skin.picture * skin.plotted
        height: Math.max(1, skin.line * 1.2)
        color: skin.ink
        opacity: 0.8
    }

    function paintDrawing(ctx) {
        ctx.reset();
        if (blankLabel)
            return;
        const p = picture, x0 = px, y0 = py;
        ctx.strokeStyle = ink;
        ctx.fillStyle = ink;
        ctx.lineCap = "round";

        // Centre lines, dash-dot, through the drawing and past it.
        ctx.lineWidth = line * 0.6;
        ctx.globalAlpha = 0.55;
        dashed(ctx, x0 - p * 0.05, y0 + p / 2, x0 + p * 1.05, y0 + p / 2);
        dashed(ctx, x0 + p / 2, y0 - p * 0.04, x0 + p / 2, y0 + p * 1.04);
        ctx.globalAlpha = 1;

        const n = cover.columns, L = levels;
        if (L.length === n * n) {
            const c = p / (n - 1);
            const at = (x, y) => L[y * n + x];

            // Hatching, the way an engraving gets its tones: the darker
            // half in lines at 45°, crossed below a third, and the darkest
            // also ruled across. The light parts stay paper.
            const bands = [{ below: 0.5, dir: 1 }, { below: 0.3, dir: -1 }, { below: 0.14, dir: 0 }];
            for (const band of bands) {
                ctx.save();
                ctx.beginPath();
                for (let y = 0; y < n; y++)
                    for (let x = 0; x < n; x++)
                        if (at(x, y) < band.below)
                            ctx.rect(x0 + (x - 0.5) * c, y0 + (y - 0.5) * c, c + 0.5, c + 0.5);
                ctx.clip();
                ctx.lineWidth = line * 0.55;
                ctx.globalAlpha = 0.6;
                ctx.beginPath();
                const gap = Math.max(2, size * 0.016);
                if (band.dir === 0) {
                    for (let d = 0; d <= p; d += gap) {
                        ctx.moveTo(x0, y0 + d);
                        ctx.lineTo(x0 + p, y0 + d);
                    }
                } else {
                    for (let d = -p; d <= p; d += gap) {
                        if (band.dir > 0) {
                            ctx.moveTo(x0 + d, y0);
                            ctx.lineTo(x0 + d + p, y0 + p);
                        } else {
                            ctx.moveTo(x0 + d + p, y0);
                            ctx.lineTo(x0 + d, y0 + p);
                        }
                    }
                }
                ctx.stroke();
                ctx.restore();
            }

            // Contours: where the brightness crosses each level, by
            // marching squares.
            ctx.lineWidth = line;
            ctx.globalAlpha = 0.95;
            ctx.beginPath();
            for (const level of [0.14, 0.3, 0.5, 0.7, 0.86]) {
                for (let y = 0; y < n - 1; y++) {
                    for (let x = 0; x < n - 1; x++) {
                        const a = at(x, y), b = at(x + 1, y), d = at(x, y + 1), e = at(x + 1, y + 1);
                        const pts = [];
                        const cross = (v1, v2, ax, ay, bx, by) => {
                            if ((v1 < level) !== (v2 < level)) {
                                const t = (level - v1) / (v2 - v1);
                                pts.push([x0 + (ax + (bx - ax) * t) * c, y0 + (ay + (by - ay) * t) * c]);
                            }
                        };
                        cross(a, b, x, y, x + 1, y);
                        cross(b, e, x + 1, y, x + 1, y + 1);
                        cross(d, e, x, y + 1, x + 1, y + 1);
                        cross(a, d, x, y, x, y + 1);
                        for (let i = 0; i + 1 < pts.length; i += 2) {
                            ctx.moveTo(pts[i][0], pts[i][1]);
                            ctx.lineTo(pts[i + 1][0], pts[i + 1][1]);
                        }
                    }
                }
            }
            ctx.stroke();
        }
        ctx.globalAlpha = 1;

        // The dimension line over the drawing: its extension lines, the
        // arrows, and the track's length on it.
        const dy = y0 - w * 0.045;
        ctx.lineWidth = line * 0.7;
        ctx.beginPath();
        ctx.moveTo(x0, y0 - w * 0.01);
        ctx.lineTo(x0, dy - w * 0.02);
        ctx.moveTo(x0 + p, y0 - w * 0.01);
        ctx.lineTo(x0 + p, dy - w * 0.02);
        ctx.stroke();
        const label = duration > 0 ? clock(duration) : "—";
        ctx.font = "600 " + Math.round(textSize) + "px monospace";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        const lw = ctx.measureText(label).width + textSize;
        ctx.beginPath();
        ctx.moveTo(x0, dy);
        ctx.lineTo(x0 + p / 2 - lw / 2, dy);
        ctx.moveTo(x0 + p / 2 + lw / 2, dy);
        ctx.lineTo(x0 + p, dy);
        ctx.stroke();
        const arrow = w * 0.025;
        for (const [x, s] of [[x0, 1], [x0 + p, -1]]) {
            ctx.beginPath();
            ctx.moveTo(x, dy);
            ctx.lineTo(x + s * arrow, dy - arrow * 0.3);
            ctx.lineTo(x + s * arrow, dy + arrow * 0.3);
            ctx.closePath();
            ctx.fill();
        }
        ctx.fillText(label, x0 + p / 2, dy);
    }
    function dashed(ctx, ax, ay, bx, by) {
        const len = Math.hypot(bx - ax, by - ay), ux = (bx - ax) / len, uy = (by - ay) / len;
        const dash = Math.max(1, size * 0.04), dot = Math.max(0.5, size * 0.006), gap = Math.max(0.5, size * 0.012);
        ctx.beginPath();
        for (let t = 0; t < len;) {
            const e = Math.min(len, t + dash);
            ctx.moveTo(ax + ux * t, ay + uy * t);
            ctx.lineTo(ax + ux * e, ay + uy * e);
            t = e + gap;
            if (t < len) {
                ctx.moveTo(ax + ux * t, ay + uy * t);
                ctx.lineTo(ax + ux * Math.min(len, t + dot), ay + uy * Math.min(len, t + dot));
            }
            t += dot + gap;
        }
        ctx.stroke();
    }
    onDurationChanged: drawing.requestPaint()
    onBlankLabelChanged: drawing.requestPaint()
    onSizeChanged: drawing.requestPaint()

    // The DETAIL circle: at rest on the drawing, under the pointer when it's
    // there.
    Item {
        id: detail
        visible: !skin.blankLabel && skin.levels.length > 0
        // Drawn once the plot is done.
        opacity: skin.plotted >= 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        readonly property real r: skin.picture * 0.13
        readonly property real rest: 0.3
        x: skin.px + skin.picture * (light.following ? 0.5 + light.lightX * 0.5 : 1 - rest) - r
        y: skin.py + skin.picture * (light.following ? 0.5 + light.lightY * 0.5 : rest) - r
        width: 2 * r
        height: 2 * r
        Behavior on x { enabled: !light.following; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !light.following; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border { width: skin.line; color: skin.ink }
        }
        Text {
            anchors { left: parent.horizontalCenter; top: parent.bottom; topMargin: skin.line * 2 }
            text: "DETAIL A"
            color: skin.ink
            font { family: "monospace"; pixelSize: Math.round(skin.textSize * 0.85); weight: Font.DemiBold }
        }
    }

    // The title block.
    Item {
        id: block
        visible: !skin.blankLabel
        x: skin.px
        width: skin.picture
        y: skin.py + skin.picture + skin.w * 0.035
        height: skin.h - skin.margin * 0.55 - skin.line * 6 - y
        // Thin lines on a sheet that turns: smoothed, or they break up.
        Rectangle {
            anchors.fill: parent
            antialiasing: true
            color: "transparent"
            border { width: skin.line; color: skin.ink }
        }
        Rectangle {
            x: parent.width * 0.68
            width: skin.line
            height: parent.height
            antialiasing: true
            color: skin.ink
        }
        Rectangle {
            y: parent.height * 0.58
            width: parent.width
            height: skin.line * 0.7
            antialiasing: true
            color: skin.ink
        }
        Text {
            x: skin.textSize * 0.5
            width: parent.width * 0.68 - skin.textSize
            height: parent.height * 0.58
            verticalAlignment: Text.AlignVCenter
            text: skin.title.toUpperCase()
            elide: Text.ElideRight
            color: skin.ink
            font { family: "monospace"; pixelSize: Math.round(skin.textSize * 1.15); weight: Font.Bold }
        }
        Text {
            x: skin.textSize * 0.5
            y: parent.height * 0.58
            width: parent.width * 0.68 - skin.textSize
            height: parent.height * 0.42
            verticalAlignment: Text.AlignVCenter
            text: "BY " + skin.artist.toUpperCase()
            elide: Text.ElideRight
            color: skin.ink
            font { family: "monospace"; pixelSize: Math.round(skin.textSize * 0.8) }
        }
        Text {
            x: parent.width * 0.68 + skin.textSize * 0.4
            height: parent.height * 0.58
            verticalAlignment: Text.AlignVCenter
            text: "DWG\n" + String(skin.hash(skin.artist + skin.title, 9000) + 1000)
            lineHeight: 0.9
            color: skin.ink
            font { family: "monospace"; pixelSize: Math.round(skin.textSize * 0.8); weight: Font.DemiBold }
        }
        Text {
            x: parent.width * 0.68 + skin.textSize * 0.4
            y: parent.height * 0.58
            height: parent.height * 0.42
            verticalAlignment: Text.AlignVCenter
            text: "1:1"
            color: skin.ink
            font { family: "monospace"; pixelSize: Math.round(skin.textSize * 0.8) }
        }
    }

    // Paused: the sheet's put on hold.
    Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -skin.h * 0.08
        width: hold.implicitWidth + skin.textSize * 1.6
        height: hold.implicitHeight + skin.textSize * 0.8
        rotation: -14
        opacity: !skin.playing && !skin.blankLabel ? 0.9 : 0
        scale: opacity > 0 ? 1 : 1.3
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.85, 0.12, 0.15, 0.12)
            radius: skin.size * 0.012
            border { width: Math.max(1.5, skin.size * 0.012); color: "#e8423f" }
        }
        Text {
            id: hold
            anchors.centerIn: parent
            text: "ON HOLD"
            color: "#e8423f"
            font { family: "monospace"; pixelSize: Math.round(skin.textSize * 1.9); weight: Font.Black; letterSpacing: skin.textSize * 0.15 }
        }
    }
}
