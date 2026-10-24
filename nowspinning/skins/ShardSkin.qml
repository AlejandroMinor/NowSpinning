// Skin: the cover on a data shard, a see-through chip with a cut corner.
//
// The cover sits on the chip like a label, with the title under it and
// circuit traces running down to a row of gold contacts. The traces and the
// chip's cyan glow pulse while playing.
//
// Under the pointer the chip turns toward it, its glow comes up and a glint
// slides across the plastic.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the bare chip.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`.
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
    property bool blankLabel: false
    property bool lightMotion: true   // the traces pulsing on their own
    property bool lightTilt: true     // the chip turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color cyan: "#00f0ff"
    readonly property color pink: "#ff2a6d"

    // The chip, and room around it for its glow.
    readonly property real w: Math.round(size * 0.78)
    readonly property real h: Math.round(w * 1.45)
    readonly property real margin: size * 0.07

    implicitWidth: Math.round(w + 2 * margin)
    implicitHeight: Math.round(h + 2 * margin)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(margin, margin, w, h)
    readonly property bool faceIsCircle: false
    // It glows instead.
    readonly property bool ownShadow: true

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // 0..1, how lit the traces are.
    property real pulse: 0.4
    SequentialAnimation on pulse {
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
    }
    readonly property real lit: light.following ? 1 : pulse

    // A label for the chip, from the title, so each track gets its own.
    readonly property string serial: {
        let n = 0;
        for (let i = 0; i < title.length; i++)
            n = (n * 31 + title.charCodeAt(i)) & 0xffff;
        return "0x" + n.toString(16).toUpperCase().padStart(4, "0");
    }

    Item {
        id: chip
        x: skin.margin
        y: skin.margin
        width: skin.w
        height: skin.h

        transform: [
            Tilt { target: chip; amount: light.lightX; degrees: 10 },
            Tilt { target: chip; amount: light.lightY; degrees: 10; vertical: true }
        ]

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: skin.cyan
            shadowBlur: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: 0.2 + 0.5 * skin.lit
        }

        Chamfer {
            id: body
            anchors.fill: parent
            cut: skin.w * 0.16
            fill: Qt.rgba(0.02, 0.14, 0.17, 0.82)
            stroke: skin.cyan
            strokeWidth: Math.max(1, skin.w * 0.01)
        }

        Text {
            x: skin.w * 0.2
            y: skin.w * 0.05
            text: "SHARD · " + (skin.blankLabel ? "----" : skin.serial)
            color: skin.cyan
            font { family: "monospace"; pixelSize: Math.max(6, Math.round(skin.w * 0.06)) }
        }

        ClippingRectangle {
            id: label
            x: skin.w * 0.1
            y: skin.w * 0.17
            width: skin.w * 0.8
            height: skin.w * 0.66
            radius: skin.w * 0.02
            color: Qt.rgba(0, 0, 0, 0.5)
            border { width: 1; color: Qt.rgba(skin.cyan.r, skin.cyan.g, skin.cyan.b, 0.4) }
            Image {
                anchors.fill: parent
                visible: !skin.blankLabel
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 400; height: 400 }
                asynchronous: true
            }
        }

        Text {
            x: label.x
            y: label.y + label.height + skin.w * 0.04
            width: label.width
            visible: !skin.blankLabel
            horizontalAlignment: Text.AlignRight
            text: skin.title
            elide: Text.ElideRight
            color: "white"
            font { family: "monospace"; pixelSize: Math.max(7, Math.round(skin.w * 0.07)); weight: Font.Bold }
        }

        // Circuit traces, from under the label down to the contacts.
        Shape {
            id: traces
            anchors.fill: parent
            opacity: skin.blankLabel ? 0.25 : 0.3 + 0.7 * skin.lit
            preferredRendererType: Shape.CurveRenderer
            readonly property real fromY: label.y + label.height + skin.w * 0.03
            readonly property real toY: contacts.y
            readonly property real lineW: Math.max(1, skin.w * 0.009)
            ShapePath {
                strokeColor: skin.cyan; strokeWidth: traces.lineW; fillColor: "transparent"
                PathPolyline {
                    path: [Qt.point(skin.w * 0.16, traces.fromY), Qt.point(skin.w * 0.16, traces.fromY + skin.w * 0.16),
                           Qt.point(skin.w * 0.3, traces.fromY + skin.w * 0.16), Qt.point(skin.w * 0.3, traces.toY)]
                }
            }
            ShapePath {
                strokeColor: skin.pink; strokeWidth: traces.lineW; fillColor: "transparent"
                PathPolyline {
                    path: [Qt.point(skin.w * 0.42, traces.fromY + skin.w * 0.1), Qt.point(skin.w * 0.42, traces.fromY + skin.w * 0.22),
                           Qt.point(skin.w * 0.56, traces.fromY + skin.w * 0.22), Qt.point(skin.w * 0.56, traces.toY)]
                }
            }
            ShapePath {
                strokeColor: skin.cyan; strokeWidth: traces.lineW; fillColor: "transparent"
                PathPolyline {
                    path: [Qt.point(skin.w * 0.86, traces.fromY + skin.w * 0.1), Qt.point(skin.w * 0.86, traces.fromY + skin.w * 0.18),
                           Qt.point(skin.w * 0.74, traces.fromY + skin.w * 0.27), Qt.point(skin.w * 0.74, traces.toY)]
                }
            }
        }

        Row {
            id: contacts
            readonly property int count: 7
            x: (skin.w - width) / 2
            y: skin.h - height - skin.w * 0.08
            spacing: skin.w * 0.035
            Repeater {
                model: contacts.count
                Rectangle {
                    width: skin.w * 0.085
                    height: skin.w * 0.14
                    radius: Math.max(1, skin.w * 0.012)
                    color: "#d8b24a"
                    border { width: 1; color: "#8a6a1e" }
                }
            }
        }

        // A glint across the plastic, following the light.
        Item {
            anchors.fill: parent
            clip: true
            opacity: light.following ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Rectangle {
                width: skin.w * 0.3
                height: skin.h * 2
                x: skin.w * 0.35 + light.lightX * skin.w * 0.6
                y: -skin.h * 0.5
                rotation: 28
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(0.8, 1, 1, 0.18) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }
    }
}
