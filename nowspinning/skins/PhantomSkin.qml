// Skin: the track as a phantom thief's calling card, in the red, black and
// white of a certain stylish JRPG.
//
// A jagged red cut-out with a black one inside, the cover in high-contrast
// black and white tinted red, slightly askew, and the title in ransom-note
// letters, each cut out on its own scrap. TAKE YOUR HEART in the corner.
// On each new track the letters drop in one by one. While playing they
// twitch on their scraps, harder with the beat when `audioLevel` comes in.
//
// Under the pointer the card turns toward it and the cover leans in.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the bare cut-outs.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `trackChangeToken` and `audioLevel`.
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
    property int trackChangeToken: 0
    property bool blankLabel: false
    property bool lightMotion: true   // the letters twitching on their own
    property bool lightTilt: true     // the card turning toward the pointer
    // How loud the low end is right now, 0..1, while `audioReact` is on
    // (AudioLevels.qml); 0 otherwise.
    property real audioLevel: 0

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color red: "#e60012"

    // The card is skewed; this is its box, with a little room for the
    // letters hanging off it.
    implicitWidth: Math.round(size * 1.04)
    implicitHeight: Math.round(size * 1.04)

    readonly property real boxFactor: implicitWidth / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Laid out on a 230 x 230 grid, scaled to the size.
    readonly property real u: implicitWidth / 230

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // Steps the letters' twitch.
    property int tick: 0
    Timer {
        interval: 240
        repeat: true
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        onTriggered: skin.tick++
    }

    // How many letters have dropped in, counting up on each new track.
    readonly property var letters: title.toUpperCase().replace(/\s+/g, " ").trim().slice(0, 11).split("")
    property real dropped: letters.length
    onTrackChangeTokenChanged: if (!blankLabel) dropping.restart()
    NumberAnimation {
        id: dropping
        target: skin
        property: "dropped"
        from: 0
        to: skin.letters.length + 1
        duration: 70 * (skin.letters.length + 1)
    }

    Item {
        id: card
        anchors.fill: parent

        transform: [
            Tilt { target: card; amount: light.lightX; degrees: 9 },
            Tilt { target: card; amount: light.lightY; degrees: 9; vertical: true }
        ]

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: skin.red
                strokeColor: "transparent"
                PathPolyline {
                    path: [Qt.point(10 * skin.u, 20 * skin.u), Qt.point(220 * skin.u, 0), Qt.point(230 * skin.u, 200 * skin.u),
                           Qt.point(0, 230 * skin.u), Qt.point(10 * skin.u, 20 * skin.u)]
                }
            }
            ShapePath {
                fillColor: "black"
                strokeColor: "transparent"
                PathPolyline {
                    path: [Qt.point(28 * skin.u, 34 * skin.u), Qt.point(206 * skin.u, 18 * skin.u), Qt.point(214 * skin.u, 168 * skin.u),
                           Qt.point(18 * skin.u, 184 * skin.u), Qt.point(28 * skin.u, 34 * skin.u)]
                }
            }
        }

        ClippingRectangle {
            x: 40 * skin.u
            y: 40 * skin.u
            width: 150 * skin.u
            height: 120 * skin.u
            rotation: -4 + (light.following ? 3 : 0)
            scale: light.following ? 1.06 : 1
            visible: !skin.blankLabel
            color: "black"
            Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            Image {
                anchors.fill: parent
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 400; height: 400 }
                asynchronous: true
                layer.enabled: true
                layer.effect: MultiEffect { saturation: -1; contrast: 0.5; colorization: 0.25; colorizationColor: skin.red }
            }
        }

        // The ransom-note title.
        Row {
            x: 14 * skin.u
            y: 178 * skin.u
            spacing: Math.max(0.5, skin.u)
            rotation: -5
            visible: !skin.blankLabel
            Repeater {
                model: skin.letters
                Rectangle {
                    id: scrap
                    required property string modelData
                    required property int index
                    readonly property real arrived: Math.max(0, Math.min(1, skin.dropped - index))
                    width: glyph.implicitWidth + 6 * skin.u
                    height: 24 * skin.u
                    color: modelData === " " ? "transparent"
                        : index % 3 === 0 ? "white" : index % 3 === 1 ? "black" : skin.red
                    opacity: arrived
                    transform: Translate { y: (1 - scrap.arrived) * -22 * skin.u }
                    rotation: ((index * 37 + skin.tick * 13) % 11 - 5) * (1 + 1.5 * skin.audioLevel)
                    Text {
                        id: glyph
                        anchors.centerIn: parent
                        text: scrap.modelData
                        color: scrap.index % 3 === 0 ? "black" : "white"
                        font {
                            family: scrap.index % 2 ? "serif" : "sans-serif"
                            pixelSize: Math.max(6, Math.round((15 + scrap.index * 7 % 5) * skin.u))
                            weight: Font.Black
                        }
                    }
                }
            }
        }

        Text {
            x: 150 * skin.u
            y: 8 * skin.u
            text: "TAKE YOUR\nHEART"
            horizontalAlignment: Text.AlignRight
            lineHeight: 0.85
            rotation: 6
            color: "white"
            font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(11 * skin.u)); weight: Font.Black; italic: true }
        }
    }
}
