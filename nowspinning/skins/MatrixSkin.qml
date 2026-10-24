// Skin: the cover behind digital rain.
//
// The cover, tinted green and dim, sits behind columns of katakana and
// digits falling at their own speeds, their glyphs changing as they go.
// The rain stops where it is when playback pauses.
//
// Under the pointer the screen turns toward it, the rain thins out and the
// cover comes through clearer, as if decoded.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the rain without the cover.
//
// See VinylSkin.qml for the skin contract.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property bool blankLabel: false
    property bool lightMotion: true   // the rain falling
    property bool lightTilt: true     // the screen turning toward the pointer
    // How loud the low end is right now, 0..1, while `audioReact` is on
    // (AudioLevels.qml); 0 otherwise, and the skin keeps its own pulse.
    property real audioLevel: 0

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color green: "#00ff66"

    implicitWidth: size
    implicitHeight: size

    readonly property real boxFactor: 1
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    readonly property real glyph: Math.max(8, Math.round(size * 0.075))
    readonly property int streams: Math.floor(size / glyph)
    readonly property int trail: 12
    readonly property bool raining: playing && lightMotion && !blankLabel

    function randomGlyph() {
        // Half-width katakana, with a digit now and then.
        return Math.random() < 0.15
            ? String.fromCharCode(0x30 + Math.floor(Math.random() * 10))
            : String.fromCharCode(0xFF66 + Math.floor(Math.random() * 56));
    }

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // How decoded the cover is: dim under the rain, clearer under the pointer.
    readonly property real clarity: light.following ? 1 : 0
    property real decoded: clarity
    Behavior on decoded { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    ClippingRectangle {
        id: screen
        anchors.fill: parent
        radius: skin.size * 0.04
        color: "black"

        transform: [
            Tilt { target: screen; amount: light.lightX; degrees: 8 },
            Tilt { target: screen; amount: light.lightY; degrees: 8; vertical: true }
        ]

        Image {
            anchors.fill: parent
            visible: !skin.blankLabel
            source: skin.blankLabel ? "" : skin.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize { width: 400; height: 400 }
            asynchronous: true
            // The beat brings the cover up through the rain for a moment.
            opacity: Math.min(1, 0.35 + 0.55 * skin.decoded + 0.3 * skin.audioLevel)
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1 - 0.6 * skin.decoded
                colorizationColor: skin.green
            }
        }

        Repeater {
            model: skin.streams
            Column {
                id: drop
                required property int index
                x: index * skin.glyph + (skin.size - skin.streams * skin.glyph) / 2
                // Each column its own speed and starting point.
                readonly property real speed: 0.6 + ((index * 37) % 11) / 11
                property real fall: ((index * 53) % 17) / 17
                y: -height + fall * (skin.size + height)
                opacity: skin.blankLabel ? 0.35 : 1 - 0.75 * skin.decoded

                NumberAnimation on fall {
                    running: true
                    paused: !skin.raining
                    loops: Animation.Infinite
                    from: 0
                    to: 1
                    duration: 2600 / drop.speed
                }

                Repeater {
                    id: glyphs
                    model: skin.trail
                    Text {
                        required property int index
                        width: skin.glyph
                        horizontalAlignment: Text.AlignHCenter
                        text: skin.randomGlyph()
                        font { family: "monospace"; pixelSize: skin.glyph }
                        // The head is the bright one; the trail fades above it.
                        color: index === skin.trail - 1 ? "#d8ffe4" : skin.green
                        opacity: (index + 1) / skin.trail
                    }
                }

                // A glyph here and there changes as it falls.
                Timer {
                    interval: 140 + (drop.index * 29) % 120
                    repeat: true
                    running: skin.raining
                    onTriggered: {
                        const g = glyphs.itemAt(Math.floor(Math.random() * skin.trail));
                        if (g)
                            g.text = skin.randomGlyph();
                    }
                }
            }
        }

        // Faint scanlines, so it reads as a screen.
        Repeater {
            model: Math.ceil(skin.size / 3)
            Rectangle {
                required property int index
                y: index * 3
                width: skin.size
                height: 1
                color: Qt.rgba(0, 0, 0, 0.18)
            }
        }
    }
}
