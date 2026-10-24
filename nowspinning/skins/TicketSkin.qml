// Skin: the track as a concert ticket.
//
// Cream card stock with the cover on the left, LIVE, the artist and the
// title beside it over a barcode, and a red ADMIT ONE stub past a
// perforated line, numbered per track. Paused, an INTERMISSION stamp lands
// across it.
//
// Under the pointer the ticket turns toward it and the stub pulls away
// along the perforation, as if about to be torn off. While playing a sheen
// runs across the card now and then.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the blank card.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title` and `artist`.
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
    property bool blankLabel: false
    property bool lightMotion: true   // the sheen now and then
    property bool lightTilt: true     // the ticket turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color stock: "#f3ead7"
    readonly property color edge: "#cdbf9f"
    readonly property color red: "#d7382f"
    readonly property color ink: "#1d1d1d"

    // Room around the ticket for its shadow and the stub pulling away.
    readonly property real w: Math.round(size * 1.4)
    readonly property real h: Math.round(w * 120 / 260)
    readonly property real margin: size * 0.05

    implicitWidth: Math.round(w + 2 * margin)
    implicitHeight: Math.round(h + 2 * margin)

    readonly property real boxFactor: implicitWidth / size
    readonly property rect faceRect: Qt.rect(margin, margin, w, h)
    readonly property bool faceIsCircle: false
    // It casts its own, stub and all.
    readonly property bool ownShadow: true

    // Laid out on a 260 x 120 grid, scaled to the size.
    readonly property real u: w / 260
    readonly property real perf: 196 * u      // where the stub tears off
    readonly property real corner: 6 * u
    readonly property real notch: 7 * u

    // A ticket number per track, from its title.
    readonly property string serial: {
        let n = 0;
        for (let i = 0; i < title.length; i++)
            n = (n * 31 + title.charCodeAt(i)) % 9000;
        return String(n + 1000);
    }

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // How far the stub has pulled away, 0..1.
    property real tear: light.following ? 1 : 0
    Behavior on tear { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    // The sheen's run across the card, -1..2; off the card outside 0..1.
    property real sheen: -1
    SequentialAnimation on sheen {
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        loops: Animation.Infinite
        PauseAnimation { duration: 3200 }
        NumberAnimation { from: -0.4; to: 1.4; duration: 1100; easing.type: Easing.InOutSine }
    }

    Item {
        id: ticket
        x: skin.margin
        y: skin.margin
        width: skin.w
        height: skin.h

        transform: [
            Tilt { target: ticket; amount: light.lightX; degrees: 8 },
            Tilt { target: ticket; amount: light.lightY; degrees: 8; vertical: true }
        ]

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.45
            shadowBlur: 0.45
            shadowVerticalOffset: 3 * skin.u
        }

        // The main part: rounded on the left, notched where it tears.
        Shape {
            id: main
            width: skin.perf
            height: skin.h
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: skin.stock
                strokeColor: skin.edge
                strokeWidth: 1
                startX: skin.corner; startY: 0
                PathLine { x: skin.perf - skin.notch; y: 0 }
                PathArc { x: skin.perf; y: skin.notch; radiusX: skin.notch; radiusY: skin.notch; direction: PathArc.Counterclockwise }
                PathLine { x: skin.perf; y: skin.h - skin.notch }
                PathArc { x: skin.perf - skin.notch; y: skin.h; radiusX: skin.notch; radiusY: skin.notch; direction: PathArc.Counterclockwise }
                PathLine { x: skin.corner; y: skin.h }
                PathArc { x: 0; y: skin.h - skin.corner; radiusX: skin.corner; radiusY: skin.corner }
                PathLine { x: 0; y: skin.corner }
                PathArc { x: skin.corner; y: 0; radiusX: skin.corner; radiusY: skin.corner }
            }
        }

        Item {
            anchors.fill: main
            visible: !skin.blankLabel

            ClippingRectangle {
                x: 10 * skin.u
                y: 10 * skin.u
                width: 100 * skin.u
                height: width
                radius: 3 * skin.u
                color: "#d9d0bb"
                Image {
                    anchors.fill: parent
                    source: skin.blankLabel ? "" : skin.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize { width: 400; height: 400 }
                    asynchronous: true
                }
            }
            Text {
                x: 118 * skin.u
                y: 11 * skin.u
                text: "LIVE"
                color: skin.red
                font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(9 * skin.u)); weight: Font.Black; letterSpacing: 3 * skin.u }
            }
            Text {
                x: 118 * skin.u
                y: 25 * skin.u
                width: 72 * skin.u
                text: skin.artist.toUpperCase()
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 0.9
                color: skin.ink
                font { family: "sans-serif"; pixelSize: Math.max(6, Math.round(13 * skin.u)); weight: Font.Black }
            }
            Text {
                x: 118 * skin.u
                y: 62 * skin.u
                width: 72 * skin.u
                text: skin.title
                elide: Text.ElideRight
                color: "#333333"
                font { family: "serif"; pixelSize: Math.max(5, Math.round(10 * skin.u)); italic: true }
            }
            Row {
                x: 118 * skin.u
                y: 84 * skin.u
                spacing: Math.max(0.5, skin.u)
                Repeater {
                    model: 22
                    Rectangle {
                        required property int index
                        width: (((index + skin.serial.charCodeAt(index % 4)) * 7) % 3 + 1) * skin.u
                        height: 18 * skin.u
                        color: skin.ink
                    }
                }
            }
        }

        // Perforation.
        Column {
            x: skin.perf - 1.5 * skin.u
            y: skin.notch + 3 * skin.u
            spacing: 5 * skin.u
            Repeater {
                model: Math.floor((skin.h - 2 * skin.notch - 6 * skin.u) / (8 * skin.u))
                Rectangle {
                    width: 3 * skin.u
                    height: width
                    radius: width / 2
                    color: skin.edge
                }
            }
        }

        // The stub, pulling away under the pointer.
        Item {
            id: stub
            x: skin.perf + skin.tear * 6 * skin.u
            width: skin.w - skin.perf
            height: skin.h
            rotation: skin.tear * 4
            transformOrigin: Item.BottomLeft

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: skin.red
                    strokeColor: Qt.darker(skin.red, 1.2)
                    strokeWidth: 1
                    startX: skin.notch; startY: 0
                    PathLine { x: stub.width - skin.corner; y: 0 }
                    PathArc { x: stub.width; y: skin.corner; radiusX: skin.corner; radiusY: skin.corner }
                    PathLine { x: stub.width; y: skin.h - skin.corner }
                    PathArc { x: stub.width - skin.corner; y: skin.h; radiusX: skin.corner; radiusY: skin.corner }
                    PathLine { x: skin.notch; y: skin.h }
                    PathArc { x: 0; y: skin.h - skin.notch; radiusX: skin.notch; radiusY: skin.notch; direction: PathArc.Counterclockwise }
                    PathLine { x: 0; y: skin.notch }
                    PathArc { x: skin.notch; y: 0; radiusX: skin.notch; radiusY: skin.notch; direction: PathArc.Counterclockwise }
                }
            }
            Text {
                x: 10 * skin.u
                y: 10 * skin.u
                visible: !skin.blankLabel
                text: "ADMIT\nONE"
                lineHeight: 0.9
                color: skin.stock
                font { family: "sans-serif"; pixelSize: Math.max(6, Math.round(12 * skin.u)); weight: Font.Black }
            }
            Text {
                x: 10 * skin.u
                y: 92 * skin.u
                visible: !skin.blankLabel
                text: "No. " + skin.serial
                color: skin.stock
                font { family: "monospace"; pixelSize: Math.max(5, Math.round(9 * skin.u)) }
            }
        }

        // The sheen.
        Item {
            anchors.fill: parent
            clip: true
            visible: skin.sheen > -0.5 && skin.sheen < 1.5
            Rectangle {
                width: skin.w * 0.25
                height: skin.h * 3
                x: skin.sheen * skin.w - width / 2
                y: -skin.h
                rotation: 25
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.3) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }

        // Paused: the intermission stamp.
        Rectangle {
            anchors.centerIn: main
            anchors.horizontalCenterOffset: 30 * skin.u
            width: stampText.implicitWidth + 14 * skin.u
            height: stampText.implicitHeight + 6 * skin.u
            rotation: -12
            color: "transparent"
            border { width: Math.max(1, 2 * skin.u); color: Qt.rgba(0.75, 0.12, 0.1, 0.8) }
            radius: 3 * skin.u
            opacity: !skin.playing && !skin.blankLabel ? 1 : 0
            scale: opacity > 0 ? 1 : 1.6
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            Text {
                id: stampText
                anchors.centerIn: parent
                text: "INTERMISSION"
                color: Qt.rgba(0.75, 0.12, 0.1, 0.8)
                font { family: "sans-serif"; pixelSize: Math.max(6, Math.round(14 * skin.u)); weight: Font.Black; letterSpacing: 2 * skin.u }
            }
        }
    }
}
