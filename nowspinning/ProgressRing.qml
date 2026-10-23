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
// This isn't a real audio spectrum: MPRIS doesn't expose audio, only
// position and duration. The wave is a plain sine; what's real is how much
// of it has been drawn.
import QtQuick

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

    onProgressChanged: cv.requestPaint()
    onAmplitudeChanged: cv.requestPaint()
    onPhaseChanged: cv.requestPaint()
    onRadiusChanged: cv.requestPaint()
    onLinearChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onPreviewChanged: cv.requestPaint()
    onColorChanged: cv.requestPaint()

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

    Canvas {
        id: cv
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const tau = Math.PI * 2;

            if (ring.preview >= 0) {
                const at = ring.pointAt(ring.preview);
                ctx.beginPath();
                ctx.arc(at.x, at.y, Math.max(3, ring.headRadius * 1.6), 0, tau);
                ctx.lineWidth = Math.max(1, ring.thickness * 0.8);
                ctx.strokeStyle = ring.color;
                ctx.stroke();
            }

            const p = Math.max(0, Math.min(1, ring.progress));
            if (p <= 0)
                return;

            // Total path length: the circumference, or the width.
            const span = ring.linear ? width - 2 * ring.headRadius
                                     : ring.radius * tau;

            // One segment per 3px of path: below that the curve gains
            // nothing and just costs more.
            const steps = Math.max(2, Math.ceil(span * p / 3));

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.lineWidth = ring.thickness;
            ctx.strokeStyle = ring.color;
            ctx.beginPath();

            let hx = 0, hy = 0;
            for (let i = 0; i <= steps; i++) {
                const t = p * (i / steps);
                const swing = ring.amplitude
                    * Math.sin(t * tau * ring.waves - ring.phase);

                if (ring.linear) {
                    hx = ring.headRadius + t * span;
                    hy = height / 2 + swing;
                } else {
                    const angle = -Math.PI / 2 + t * tau;   // starts at 12 o'clock
                    const rr = ring.radius + swing;
                    hx = width / 2 + rr * Math.cos(angle);
                    hy = height / 2 + rr * Math.sin(angle);
                }

                if (i === 0)
                    ctx.moveTo(hx, hy);
                else
                    ctx.lineTo(hx, hy);
            }
            ctx.stroke();

            if (ring.headRadius > 0) {
                ctx.beginPath();
                ctx.arc(hx, hy, ring.headRadius, 0, tau);
                ctx.fillStyle = ring.color;
                ctx.fill();
            }
        }
    }
}
