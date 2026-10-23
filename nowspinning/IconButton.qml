// A transport control button. The icon is hand-drawn: it doesn't depend on
// an icon font being installed.
import QtQuick

Item {
    id: btn

    property string kind: "play"   // prev | play | pause | next | size | skin | gear | toggle
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
            } else if (btn.kind === "size") {
                // Two arrows pulling apart along the diagonal.
                const a = s * 0.95, head = s * 0.55;
                ctx.lineWidth = Math.max(1.2, width * 0.075);
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(cx - a, cy + a);
                ctx.lineTo(cx + a, cy - a);
                ctx.moveTo(cx + a - head, cy - a);
                ctx.lineTo(cx + a, cy - a);
                ctx.lineTo(cx + a, cy - a + head);
                ctx.moveTo(cx - a + head, cy + a);
                ctx.lineTo(cx - a, cy + a);
                ctx.lineTo(cx - a, cy + a - head);
                ctx.stroke();
            } else if (btn.kind === "skin") {
                // A disc: outline, label ring, and the hole.
                ctx.lineWidth = Math.max(1.2, width * 0.075);
                ctx.beginPath();
                ctx.arc(cx, cy, s * 1.05, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, s * 0.42, 0, Math.PI * 2);
                ctx.fill();
            } else if (btn.kind === "gear") {
                // Six chunky teeth around a ring, and the hole: fewer and
                // fatter than a real gear, so it still reads at 10px.
                const g = width * 0.5;
                ctx.save();
                ctx.translate(cx, cy);
                for (let i = 0; i < 6; i++) {
                    ctx.rotate(Math.PI / 3);
                    ctx.fillRect(-g * 0.22, -g * 0.98, g * 0.44, g * 0.5);
                }
                ctx.restore();
                ctx.beginPath();
                ctx.arc(cx, cy, g * 0.68, 0, Math.PI * 2);
                ctx.arc(cx, cy, g * 0.28, 0, Math.PI * 2, true);
                ctx.fill();
            } else if (btn.kind === "toggle") {
                // A switch, on.
                ctx.lineWidth = Math.max(1.2, width * 0.075);
                const sw = s * 1.0, sh = s * 0.55;
                ctx.beginPath();
                ctx.moveTo(cx - sw + sh, cy - sh);
                ctx.lineTo(cx + sw - sh, cy - sh);
                ctx.arc(cx + sw - sh, cy, sh, -Math.PI / 2, Math.PI / 2);
                ctx.lineTo(cx - sw + sh, cy + sh);
                ctx.arc(cx - sw + sh, cy, sh, Math.PI / 2, Math.PI * 1.5);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx + sw - sh, cy, sh * 0.55, 0, Math.PI * 2);
                ctx.fill();
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
