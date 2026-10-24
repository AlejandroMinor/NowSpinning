// Skin: the track as a postage stamp.
//
// A white stamp with a perforated edge, the cover as its picture, the
// artist and title under it and the track's length as its value, in cents.
// Each new track gets postmarked: the PLAYED cancellation, with today's
// date, comes down on its corner. Paused, the colours fade a little, like
// an old stamp.
//
// Under the pointer the stamp turns toward it and lifts off the page, its
// shadow growing under it.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the stamp without its picture.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist`, `duration` and
// `trackChangeToken`.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property string artist: ""
    property real duration: 0
    property int trackChangeToken: 0
    property bool blankLabel: false
    property bool lightTilt: true     // the stamp turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color paper: "#fbf7ee"
    readonly property color wine: "#7a1018"

    // The stamp, and room around it for its shadow.
    readonly property real w: Math.round(size * 0.92)
    readonly property real h: Math.round(w * 1.2)
    readonly property real margin: size * 0.05

    implicitWidth: Math.round(w + 2 * margin)
    implicitHeight: Math.round(h + 2 * margin)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(margin, margin, w, h)
    readonly property bool faceIsCircle: false
    // It casts its own, lifting under the pointer.
    readonly property bool ownShadow: true

    // Laid out on a 200 x 240 grid, scaled to the size.
    readonly property real u: w / 200

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    property real lift: light.following ? 1 : 0
    Behavior on lift { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // The postmark coming down, 0 (in the air) to 1 (on the stamp).
    property real mark: 1
    onTrackChangeTokenChanged: if (!blankLabel) marking.restart()
    NumberAnimation {
        id: marking
        target: skin
        property: "mark"
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutBack
    }
    readonly property string today: new Date().toLocaleDateString(Qt.locale("en_US"), "dd MMM yy").toUpperCase()

    // The outline: a rectangle with half-circle bites all round.
    readonly property real hole: 6 * u
    readonly property var outline: {
        const pts = [];
        const r = hole;
        const edge = (x0, y0, x1, y1, n, nx, ny) => {
            // Along one side, n bites, the inward normal (nx, ny).
            const len = Math.hypot(x1 - x0, y1 - y0);
            const dx = (x1 - x0) / len, dy = (y1 - y0) / len;
            for (let i = 0; i < n; i++) {
                const c = (i + 0.5) / n * len;
                const cx = x0 + dx * c, cy = y0 + dy * c;
                for (let s = 0; s <= 6; s++) {
                    const a = Math.PI * s / 6;
                    // From the near side of the bite, in and round to the far side.
                    const along = -Math.cos(a) * r, into = Math.sin(a) * r;
                    pts.push(Qt.point(cx + dx * along + nx * into, cy + dy * along + ny * into));
                }
            }
        };
        const across = Math.max(6, Math.round(w / (4.2 * r)));
        const down = Math.max(7, Math.round(h / (4.2 * r)));
        pts.push(Qt.point(0, 0));
        edge(0, 0, w, 0, across, 0, 1);
        pts.push(Qt.point(w, 0));
        edge(w, 0, w, h, down, -1, 0);
        pts.push(Qt.point(w, h));
        edge(w, h, 0, h, across, 0, -1);
        pts.push(Qt.point(0, h));
        edge(0, h, 0, 0, down, 1, 0);
        pts.push(Qt.point(0, 0));
        return pts;
    }

    Item {
        id: stamp
        x: skin.margin
        y: skin.margin
        width: skin.w
        height: skin.h
        scale: 1 + 0.03 * skin.lift

        transform: [
            Tilt { target: stamp; amount: light.lightX; degrees: 8 },
            Tilt { target: stamp; amount: light.lightY; degrees: 8; vertical: true }
        ]

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.35 + 0.2 * skin.lift
            shadowBlur: 0.3 + 0.4 * skin.lift
            shadowVerticalOffset: (2 + 6 * skin.lift) * skin.u
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: skin.paper
                strokeColor: "transparent"
                PathPolyline { path: skin.outline }
            }
        }

        ClippingRectangle {
            x: 18 * skin.u
            y: 18 * skin.u
            width: 164 * skin.u
            height: width
            color: "#e9e2d2"
            Image {
                anchors.fill: parent
                visible: !skin.blankLabel
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 400; height: 400 }
                asynchronous: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: skin.playing ? -0.2 : -0.6
                    contrast: 0.15
                }
            }
        }

        Text {
            x: 18 * skin.u
            y: 188 * skin.u
            width: 120 * skin.u
            visible: !skin.blankLabel
            text: skin.artist.toUpperCase()
            elide: Text.ElideRight
            color: skin.wine
            font { family: "serif"; pixelSize: Math.max(6, Math.round(12 * skin.u)); weight: Font.Bold; letterSpacing: 1 * skin.u }
        }
        Text {
            x: 18 * skin.u
            y: 204 * skin.u
            width: 120 * skin.u
            visible: !skin.blankLabel
            text: skin.title
            elide: Text.ElideRight
            color: "#333333"
            font { family: "serif"; pixelSize: Math.max(5, Math.round(10 * skin.u)); italic: true }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18 * skin.u
            y: 186 * skin.u
            visible: !skin.blankLabel
            text: Math.max(1, Math.round(skin.duration / 60)) + "¢"
            color: skin.wine
            font { family: "serif"; pixelSize: Math.max(8, Math.round(26 * skin.u)); weight: Font.Black }
        }

        // The postmark.
        Item {
            x: 104 * skin.u
            y: 112 * skin.u
            width: 80 * skin.u
            height: width
            rotation: -14
            visible: !skin.blankLabel
            opacity: 0.55 * Math.min(1, skin.mark)
            scale: 1.8 - 0.8 * skin.mark
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border { width: Math.max(1, 2 * skin.u); color: "#1a1a1a" }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 10 * skin.u
                radius: width / 2
                color: "transparent"
                border { width: 1; color: "#1a1a1a" }
            }
            Text {
                anchors.centerIn: parent
                text: "PLAYED\n" + skin.today
                horizontalAlignment: Text.AlignHCenter
                color: "#1a1a1a"
                font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(9 * skin.u)); weight: Font.Bold }
            }
            // The wavy cancellation lines, trailing off to the left.
            Column {
                x: -48 * skin.u
                y: 26 * skin.u
                spacing: 6 * skin.u
                Repeater {
                    model: 3
                    Rectangle { width: 44 * skin.u; height: Math.max(1, 2 * skin.u); color: "#1a1a1a" }
                }
            }
        }
    }
}
