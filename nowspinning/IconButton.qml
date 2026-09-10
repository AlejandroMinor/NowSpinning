// A transport control button. The icon is hand-drawn: it doesn't depend on
// an icon font being installed.
import QtQuick

Item {
    id: btn

    property string kind: "play"   // prev | play | pause | next
    property bool active: true
    property color tint: "white"
    signal activated()

    opacity: active ? (hh.hovered ? 1.0 : 0.82) : 0.25
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Canvas {
        id: cv
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = btn.tint;
            ctx.strokeStyle = btn.tint;

            const cx = width / 2, cy = height / 2;
            const s = width * 0.28;   // icon half-height

            // Draws one triangle pointing left or right, tip at `tipX`.
            function drawTriangle(tipX, pointingRight) {
                const direction = pointingRight ? 1 : -1;
                ctx.beginPath();
                ctx.moveTo(tipX - direction * s * 0.5, cy - s);
                ctx.lineTo(tipX + direction * s * 0.5, cy);
                ctx.lineTo(tipX - direction * s * 0.5, cy + s);
                ctx.closePath();
                ctx.fill();
            }

            if (btn.kind === "play") {
                drawTriangle(cx + s * 0.15, true);
            } else if (btn.kind === "pause") {
                const bw = s * 0.34, gap = s * 0.34;
                ctx.fillRect(cx - gap - bw, cy - s, bw, s * 2);
                ctx.fillRect(cx + gap, cy - s, bw, s * 2);
            } else if (btn.kind === "next") {
                drawTriangle(cx - s * 0.40, true);
                drawTriangle(cx + s * 0.40, true);
                ctx.fillRect(cx + s * 0.78, cy - s, s * 0.22, s * 2);
            } else if (btn.kind === "prev") {
                drawTriangle(cx + s * 0.40, false);
                drawTriangle(cx - s * 0.40, false);
                ctx.fillRect(cx - s * 1.00, cy - s, s * 0.22, s * 2);
            }
        }
    }

    onKindChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onTintChanged: cv.requestPaint()

    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (btn.active) btn.activated() }
}
