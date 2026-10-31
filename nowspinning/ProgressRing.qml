// Playback progress, drawn as a wavy trail that grows and ends in a dot.
// Circular around the disc, or straight inside the controls overlay: same
// wave either way, only the path it travels changes.
//
// Only the traveled stretch gets drawn, no dim ring behind it. That's what
// makes it read as a snake moving along its path, and it's also half the
// per-frame work.
//
// The ring itself doesn't rotate. If it did, the finish line would move and
// you'd lose the ability to read "how much is left" at a glance. What moves
// is the wave's phase: the crests travel along a path that stays put.
//
// MPRIS doesn't expose audio, only position and duration, so on its own
// the wave is a plain sine; what's real is how much of it has been drawn.
// Given `levels` (AudioLevels.qml, from cava), it follows the music
// instead: each stretch of the path swings as hard as its band is loud,
// with a second, faster wave mixed in, like a trace on an oscilloscope.
// Around the ring the bands run out from the top both ways, lows at 12
// o'clock; along the bar, lows on the left.
import QtQuick
import QtQuick.Shapes

Item {
    id: ring

    property bool linear: false      // straight path instead of circular
    property real progress: 0        // 0..1
    property real radius: 60         // px from center to the wave's axis
    property real amplitude: 4       // px the wave rises and falls
    property int waves: 14           // full cycles along the whole path
    property real thickness: 2
    property real headRadius: 3      // the dot at the tip
    property color color: Qt.rgba(1, 1, 1, 0.55)

    // Where a click would jump to, 0..1, drawn as a hollow dot on the path.
    // -1 draws nothing.
    property real preview: -1

    // The wave travels along its path while playback is active.
    property bool flowing: false
    property real flowSpeed: 2.8     // radians per second
    property real phase: 0

    // Band levels, 0..1, lows first. Empty = the plain sine.
    property var levels: []

    // How loud the music is at `t` (0..1 along the whole path), between
    // the two nearest bands.
    function levelAt(t) {
        const n = levels.length;
        if (n === 0)
            return 0;
        const u = linear ? t : 1 - Math.abs(2 * t - 1);
        const f = Math.max(0, Math.min(n - 1, u * (n - 1)));
        const i = Math.floor(f);
        const j = Math.min(n - 1, i + 1);
        return levels[i] + (levels[j] - levels[i]) * (f - i);
    }

    // While the wave flows, its tick repaints 30 times a second anyway, so
    // a new level (cava sends 30 a second too) or a step of progress waits
    // for it: one paint per frame instead of two or three out of step. And
    // nothing paints while hidden (the controls' bar, most of the time): a
    // hidden Canvas still paints when asked. It catches up on showing.
    function repaint() {
        if (visible)
            cv.requestPaint();
    }
    function step() {
        if (!flowing)
            repaint();
    }
    onVisibleChanged: repaint()
    onProgressChanged: step()
    onAmplitudeChanged: step()
    onPhaseChanged: repaint()
    onRadiusChanged: repaint()
    onLinearChanged: repaint()
    onWidthChanged: repaint()
    onPreviewChanged: repaint()
    onColorChanged: repaint()
    onLevelsChanged: step()

    // The point `t` (0..1) of the way along the path, on its axis: no wave.
    function pointAt(t) {
        if (linear)
            return Qt.point(headRadius + t * (width - 2 * headRadius), height / 2);
        const angle = -Math.PI / 2 + t * Math.PI * 2;
        return Qt.point(width / 2 + radius * Math.cos(angle),
                        height / 2 + radius * Math.sin(angle));
    }

    // The inverse: how far along the path a point sits, or -1 if it's not
    // close enough to the path to count. `reach` is how far off the axis
    // still counts, in px.
    function fractionAt(x, y, reach) {
        if (linear) {
            if (Math.abs(y - height / 2) > reach)
                return -1;
            return Math.max(0, Math.min(1,
                (x - headRadius) / Math.max(1, width - 2 * headRadius)));
        }
        const dx = x - width / 2;
        const dy = y - height / 2;
        if (Math.abs(Math.sqrt(dx * dx + dy * dy) - radius) > reach)
            return -1;
        // Starts at 12 o'clock and runs clockwise, same as the drawing.
        const t = (Math.atan2(dy, dx) + Math.PI / 2) / (Math.PI * 2);
        return t < 0 ? t + 1 : t;
    }

    // 30 fps, not 60: the wave completes a cycle every 2.2s, so that's still
    // ~67 frames per cycle. Repainting the canvas at double that rate cost
    // three times the CPU with no visible difference.
    Timer {
        interval: 33
        repeat: true
        running: ring.flowing

        property double last: 0
        onRunningChanged: last = Date.now()

        onTriggered: {
            const now = Date.now();
            const dt = Math.min(0.05, (now - last) / 1000);
            last = now;
            ring.phase = (ring.phase + ring.flowSpeed * dt) % (Math.PI * 2);
        }
    }

    // The wave as a Shape, traced on the GPU by the curve renderer: drawn
    // in a Canvas it was rasterised on the CPU and uploaded 30 times a
    // second, the most expensive thing on screen. Same stroke, same round
    // ends. Rebuilt at most once per frame, whatever asked for it.
    QtObject {
        id: cv
        property bool pending: false
        function requestPaint() {
            if (pending)
                return;
            pending = true;
            Qt.callLater(rebuild);
        }
        function rebuild() {
            pending = false;
            const tau = Math.PI * 2;
            const p = Math.max(0, Math.min(1, ring.progress));
            if (p <= 0) {
                poly.path = [];
                head.visible = false;
                return;
            }
            const span = ring.linear ? ring.width - 2 * ring.headRadius : ring.radius * tau;
            const steps = Math.max(2, Math.ceil(span * p / 3));
            const L = ring.levels, n = L.length, heard = n > 0;
            const linear = ring.linear, amp = ring.amplitude, phase = ring.phase;
            const waves = ring.waves, headR = ring.headRadius, radius = ring.radius;
            const cx = ring.width / 2, cy = ring.height / 2;
            const pts = new Array(steps + 1);
            let hx = 0, hy = 0;
            for (let i = 0; i <= steps; i++) {
                const t = p * (i / steps);
                const k = t * tau * waves;
                let swing;
                if (heard) {
                    const u = linear ? t : 1 - Math.abs(2 * t - 1);
                    const f = Math.max(0, Math.min(n - 1, u * (n - 1)));
                    const a = Math.floor(f), b = Math.min(n - 1, a + 1);
                    const level = L[a] + (L[b] - L[a]) * (f - a);
                    swing = amp * (0.3 + 1.6 * level)
                        * (0.7 * Math.sin(k - phase) + 0.3 * Math.sin(k * 2.7 + phase * 2));
                } else {
                    swing = amp * Math.sin(k - phase);
                }
                if (linear) {
                    hx = headR + t * span;
                    hy = cy + swing;
                } else {
                    const angle = -Math.PI / 2 + t * tau;
                    const rr = radius + swing;
                    hx = cx + rr * Math.cos(angle);
                    hy = cy + rr * Math.sin(angle);
                }
                pts[i] = Qt.point(hx, hy);
            }
            poly.path = pts;
            head.x = hx - headR;
            head.y = hy - headR;
            head.visible = headR > 0;
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: ring.color
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { id: poly }
        }
    }
    Rectangle {
        id: head
        visible: false
        width: ring.headRadius * 2
        height: width
        radius: width / 2
        color: ring.color
        antialiasing: true
    }
    Rectangle {
        readonly property real r: Math.max(3, ring.headRadius * 1.6)
        readonly property point at: ring.preview >= 0 ? ring.pointAt(ring.preview) : Qt.point(0, 0)
        visible: ring.preview >= 0
        x: at.x - r
        y: at.y - r
        width: r * 2
        height: width
        radius: r
        color: "transparent"
        border { width: Math.max(1, ring.thickness * 0.8); color: ring.color }
        antialiasing: true
    }
}
