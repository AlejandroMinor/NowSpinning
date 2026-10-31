// Skin: the cover as a stained glass window.
//
// An arched window in a stone frame, its glass cut into pieces, each the
// colour of the cover where it sits (a little richer: glass is never
// quite black or white), held together by lead and two iron bars. A new
// track is a new window, cut its own way.
//
// The light comes through from behind: a bright patch on the glass where
// the sun is, drifting while playing (lightMotion) or following the pointer
// (lightTilt), and the window's colours cast on the wall around it, away
// from the light. Paused, the sun goes behind a cloud.
//
// The back, for the track info, is the window at night.
//
// See VinylSkin.qml for the skin contract.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property bool blankLabel: false
    property bool lightMotion: true   // the sun drifting on its own
    property bool lightTilt: true     // the sun following the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // The window and its frame; room around it for the light it casts.
    readonly property real w: Math.round(size * 0.82)
    readonly property real h: Math.round(w * 1.32)
    // Room for the light it casts, blur and drift included, so the window
    // never cuts it off in a straight line.
    readonly property real pad: Math.round(size * 0.12)
    readonly property real frame: w * 0.07
    // The glass, inside the frame.
    readonly property real gw: w - 2 * frame
    readonly property real gh: h - 2 * frame

    implicitWidth: w + 2 * pad
    implicitHeight: h + 2 * pad

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(pad, pad, w, h)
    readonly property bool faceIsCircle: false
    // Its shadow is the coloured light it casts.
    readonly property bool ownShadow: true

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: skin.lightMotion
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // How bright the sun is: full while playing or under the pointer.
    readonly property real sun: blankLabel ? 0 : playing || light.following ? 1 : 0.35
    property real shine: sun
    Behavior on shine { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }

    CoverPixels {
        id: cover
        source: skin.blankLabel ? "" : skin.artUrl
        columns: 48
        // The glass is always the same shape (h is w * 1.32, less the
        // frame): a fixed grid, or a size settling would resample it.
        rows: 66
        onSampled: skin.recut()
    }

    function hash(s) {
        let n = 17;
        for (let i = 0; i < s.length; i++)
            n = (n * 31 + s.charCodeAt(i)) % 2147483647;
        return n;
    }

    // The arch, as a path on a 2D context: straight sides, a round top.
    function arch(ctx, x, y, width, height) {
        const r = width / 2;
        ctx.beginPath();
        ctx.moveTo(x, y + height);
        ctx.lineTo(x, y + r);
        ctx.arc(x + r, y + r, r, Math.PI, 2 * Math.PI, false);
        ctx.lineTo(x + width, y + height);
        ctx.closePath();
    }

    // The pieces: a Voronoi cut around points scattered over the glass,
    // thicker where the cover has edges (a face, a horizon) and sparse where
    // it's flat (a sky), the way a glazier would cut it. Worked out once per
    // cover.
    property var pieces: []
    // A new cover and a new size often come together: cut once for both.
    function recut() {
        Qt.callLater(cut);
    }
    function cut() {
        if (gw <= 0 || gh <= 0)
            return;
        const px = cover.pixels, n = cover.columns, m = cover.rows;
        const has = px.length === n * m * 3;
        const lum = i => (0.299 * px[i * 3] + 0.587 * px[i * 3 + 1] + 0.114 * px[i * 3 + 2]) / 255;
        // How much the cover changes around a cell, 0..1.
        const edge = (cx, cy) => {
            if (!has)
                return 0.4;
            const x = Math.min(n - 2, Math.max(1, cx)), y = Math.min(m - 2, Math.max(1, cy));
            const gx = lum(y * n + x + 1) - lum(y * n + x - 1);
            const gy = lum((y + 1) * n + x) - lum((y - 1) * n + x);
            return Math.min(1, Math.hypot(gx, gy) * 3);
        };

        const cols = 21, rows = 29;
        const cw = gw / cols, ch = gh / rows;
        let s = hash(artUrl) || 1;
        const rand = () => (s = (s * 16807) % 2147483647) / 2147483647;
        // One point at most per cell of a grid, so a piece only needs the
        // points in the cells around its own to be cut.
        const seeds = [], grid = new Array(cols * rows).fill(null);
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                const x = (c + 0.15 + 0.7 * rand()) * cw, y = (r + 0.15 + 0.7 * rand()) * ch;
                const keep = 0.4 + 0.6 * edge(Math.floor(x / gw * n), Math.floor(y / gh * m));
                if (rand() < keep) {
                    const seed = { x: x, y: y, r: r, c: c };
                    seeds.push(seed);
                    grid[r * cols + c] = seed;
                }
            }
        }
        const cell = Math.min(cw, ch);

        const out = [];
        for (const a of seeds) {
            let poly = [[0, 0], [gw, 0], [gw, gh], [0, gh]];
            let far = Math.hypot(gw, gh);
            // The cells around a's, ring by ring, the nearest first: once a
            // ring is farther than twice the piece's farthest corner, nothing
            // beyond it can cut the piece.
            const near = [];
            for (let k = 1; k < Math.max(cols, rows); k++) {
                if ((k - 1) * cell > 2 * far)
                    break;
                near.length = 0;
                for (let r = a.r - k; r <= a.r + k; r++) {
                    if (r < 0 || r >= rows)
                        continue;
                    const edgeRow = r === a.r - k || r === a.r + k;
                    for (let c = a.c - k; c <= a.c + k; c += edgeRow ? 1 : 2 * k) {
                        if (c >= 0 && c < cols && grid[r * cols + c])
                            near.push(grid[r * cols + c]);
                    }
                }
            for (const b of near) {
                const d = Math.hypot(b.x - a.x, b.y - a.y);
                if (d > 2 * far)
                    continue;
                // Keep the side of the line halfway between them nearer a.
                const nx = b.x - a.x, ny = b.y - a.y;
                const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
                const side = p => (p[0] - mx) * nx + (p[1] - my) * ny;
                const next = [];
                for (let i = 0; i < poly.length; i++) {
                    const p = poly[i], q = poly[(i + 1) % poly.length];
                    const sp = side(p), sq = side(q);
                    if (sp <= 0)
                        next.push(p);
                    if ((sp < 0) !== (sq < 0) && sp !== sq) {
                        const t = sp / (sp - sq);
                        next.push([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]);
                    }
                }
                poly = next;
                if (poly.length < 3)
                    break;
                far = 0;
                for (const p of poly)
                    far = Math.max(far, Math.hypot(p[0] - a.x, p[1] - a.y));
            }
                if (poly.length < 3)
                    break;
            }
            if (poly.length < 3)
                continue;
            let cx = 0, cy = 0;
            for (const p of poly) {
                cx += p[0];
                cy += p[1];
            }
            cx /= poly.length;
            cy /= poly.length;
            out.push({ poly: poly, cx: cx, cy: cy, color: tint(cx, cy, poly) });
        }
        pieces = out;
        glass.requestPaint();
        lead.requestPaint();
    }

    // A piece's colour: the cover's, averaged over every cell the piece
    // covers, made a little richer and kept off black and white. Without a
    // cover, night blue.
    function tint(cx, cy, poly) {
        const px = cover.pixels, n = cover.columns, m = cover.rows;
        if (px.length !== n * m * 3)
            return Qt.rgba(0.08, 0.1, 0.16, 1);
        let minX = gw, minY = gh, maxX = 0, maxY = 0;
        for (const p of poly) {
            minX = Math.min(minX, p[0]);
            minY = Math.min(minY, p[1]);
            maxX = Math.max(maxX, p[0]);
            maxY = Math.max(maxY, p[1]);
        }
        const inside = (x, y) => {
            let odd = false;
            for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
                const a = poly[i], b = poly[j];
                if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0])
                    odd = !odd;
            }
            return odd;
        };
        let r = 0, g = 0, b = 0, k = 0;
        const add = (gx, gy) => {
            const i = (gy * n + gx) * 3;
            r += px[i];
            g += px[i + 1];
            b += px[i + 2];
            k++;
        };
        const x1 = Math.max(0, Math.floor(minX / gw * n)), x2 = Math.min(n - 1, Math.floor(maxX / gw * n));
        const y1 = Math.max(0, Math.floor(minY / gh * m)), y2 = Math.min(m - 1, Math.floor(maxY / gh * m));
        for (let gy = y1; gy <= y2; gy++)
            for (let gx = x1; gx <= x2; gx++)
                if (inside((gx + 0.5) / n * gw, (gy + 0.5) / m * gh))
                    add(gx, gy);
        // A sliver smaller than a cell: the cell under its middle.
        if (k === 0)
            add(Math.min(n - 1, Math.max(0, Math.floor(cx / gw * n))),
                Math.min(m - 1, Math.max(0, Math.floor(cy / gh * m))));
        const c = Qt.rgba(r / k / 255, g / k / 255, b / k / 255, 1);
        return Qt.hsla(c.hslHue < 0 ? 0 : c.hslHue,
                       Math.min(1, c.hslSaturation * 1.2 + 0.05),
                       0.07 + c.hslLightness * 0.83, 1);
    }

    // The colours on the wall, cast away from the light.
    MultiEffect {
        source: glass
        x: skin.pad + skin.frame - light.lightX * skin.size * 0.03
        y: skin.pad + skin.frame + skin.size * 0.015 - light.lightY * skin.size * 0.025
        width: glass.width
        height: glass.height
        scale: 1.04
        blurEnabled: true
        blur: 1
        blurMax: Math.round(Math.min(64, skin.size * 0.08))
        autoPaddingEnabled: true
        saturation: 0.6
        brightness: 0.2
        opacity: 0.85 * skin.shine
        visible: opacity > 0.01
    }

    // The stone frame.
    Canvas {
        id: stone
        x: skin.pad
        y: skin.pad
        width: skin.w
        height: skin.h
        // Its own size spelled out, and painted again on any change: left
        // to itself, a Canvas that grows keeps the old size's drawing,
        // and the arch spills past the bottom.
        canvasSize: Qt.size(width, height)
        onCanvasSizeChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const grad = ctx.createLinearGradient(0, 0, width, height);
            grad.addColorStop(0, "#d6cdb8");
            grad.addColorStop(1, "#a59a84");
            ctx.fillStyle = grad;
            skin.arch(ctx, 0, 0, width, height);
            ctx.fill();
            ctx.strokeStyle = "rgba(60, 50, 40, 0.5)";
            ctx.lineWidth = Math.max(1, skin.size * 0.006);
            ctx.stroke();
        }
    }

    // The glass: the pieces, each a little lighter in its middle.
    Canvas {
        id: glass
        x: skin.pad + skin.frame
        y: skin.pad + skin.frame
        width: skin.gw
        height: skin.gh
        canvasSize: Qt.size(width, height)
        onCanvasSizeChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            skin.arch(ctx, 0, 0, width, height);
            ctx.clip();
            ctx.fillStyle = "#151820";
            ctx.fillRect(0, 0, width, height);
            for (const piece of skin.pieces) {
                const c = skin.blankLabel ? Qt.rgba(0.1, 0.12, 0.2, 1) : piece.color;
                ctx.beginPath();
                ctx.moveTo(piece.poly[0][0], piece.poly[0][1]);
                for (let i = 1; i < piece.poly.length; i++)
                    ctx.lineTo(piece.poly[i][0], piece.poly[i][1]);
                ctx.closePath();
                ctx.fillStyle = c;
                ctx.fill();
                let reach = 0;
                for (const p of piece.poly)
                    reach = Math.max(reach, Math.hypot(p[0] - piece.cx, p[1] - piece.cy));
                const grad = ctx.createRadialGradient(piece.cx, piece.cy, 0, piece.cx, piece.cy, reach);
                grad.addColorStop(0, "rgba(255, 255, 255, 0.1)");
                grad.addColorStop(1, "rgba(0, 0, 0, 0.14)");
                ctx.fillStyle = grad;
                ctx.fill();
            }
            ctx.restore();
        }
    }

    // Where the sun is behind the glass, brighter there.
    Item {
        id: sunlit
        x: glass.x
        y: glass.y
        width: glass.width
        height: glass.height
        visible: skin.shine > 0.01
        opacity: skin.shine

        Item {
            id: spot
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Shape {
                id: sunShape
                readonly property real cx: spot.width * (0.5 + light.lightX * 0.38)
                readonly property real cy: spot.height * (0.42 + light.lightY * 0.3)
                readonly property real r: spot.width * 0.75
                anchors.fill: parent
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: sunShape.cx; centerY: sunShape.cy
                        focalX: centerX; focalY: centerY
                        centerRadius: sunShape.r
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 1) }
                        GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                    }
                    PathRectangle { x: 0; y: 0; width: spot.width; height: spot.height }
                }
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: glass
            brightness: 0.32
            saturation: 0.3
            maskEnabled: true
            maskSource: spot
            maskThresholdMin: 0
            maskSpreadAtMin: 1
        }
    }

    // The lead between the pieces, and the iron bars across them.
    Canvas {
        id: lead
        x: glass.x
        y: glass.y
        width: glass.width
        height: glass.height
        canvasSize: Qt.size(width, height)
        onCanvasSizeChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            skin.arch(ctx, 0, 0, width, height);
            ctx.clip();
            ctx.lineJoin = "round";
            const lw = Math.max(1, skin.size * 0.011);
            for (const pass of [{ color: "#26272b", width: lw }, { color: "rgba(150, 150, 160, 0.35)", width: lw * 0.3 }]) {
                ctx.strokeStyle = pass.color;
                ctx.lineWidth = pass.width;
                for (const piece of skin.pieces) {
                    ctx.beginPath();
                    ctx.moveTo(piece.poly[0][0], piece.poly[0][1]);
                    for (let i = 1; i < piece.poly.length; i++)
                        ctx.lineTo(piece.poly[i][0], piece.poly[i][1]);
                    ctx.closePath();
                    ctx.stroke();
                }
            }
            ctx.fillStyle = "#1c1d21";
            for (const f of [0.52, 0.76])
                ctx.fillRect(0, height * f - lw * 0.7, width, lw * 1.4);
            ctx.restore();
            ctx.strokeStyle = "#26272b";
            ctx.lineWidth = lw * 2;
            skin.arch(ctx, 0, 0, width, height);
            ctx.stroke();
        }
    }

    onBlankLabelChanged: glass.requestPaint()
    onGwChanged: recut()
}
