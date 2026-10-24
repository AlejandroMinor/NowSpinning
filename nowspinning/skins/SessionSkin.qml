// Skin: the track as a session title card, the way a certain space western
// opened its episodes: flat blocks of red, blue and mustard on cream, the
// cover cut into them, condensed type underneath.
//
// While playing the blocks slide past each other, slowly, and jump a little
// with the beat when `audioLevel` comes in. Paused, the card turns into the
// end card. Each new track gets its own session number.
//
// Under the pointer the card turns toward it and the blocks drift the other
// way, a step of parallax.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the bare blocks.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title` and `audioLevel`.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property bool blankLabel: false
    property bool lightMotion: true   // the blocks sliding on their own
    property bool lightTilt: true     // the card turning toward the pointer
    // How loud the low end is right now, 0..1, while `audioReact` is on
    // (AudioLevels.qml); 0 otherwise.
    property real audioLevel: 0

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color cream: "#f2e6c9"
    readonly property color red: "#d7382f"
    readonly property color blue: "#1f4e8c"
    readonly property color mustard: "#f2b81d"
    readonly property color ink: "#111111"

    implicitWidth: size
    implicitHeight: Math.round(size * 250 / 230)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Laid out on a 230 x 250 grid, scaled to the size.
    readonly property real u: size / 230

    // A session number per track, from its title.
    readonly property int session: {
        let n = 0;
        for (let i = 0; i < title.length; i++)
            n = (n * 31 + title.charCodeAt(i)) % 26;
        return n + 1;
    }

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // 0..1, how far the blocks have slid.
    property real slide: 0
    SequentialAnimation on slide {
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 1400 }
        NumberAnimation { to: 0; duration: 2200; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 1400 }
    }
    // Sideways shift: the parallax against the pointer, plus the beat.
    readonly property real drift: (-light.lightX * 8 + audioLevel * 6) * u

    ClippingRectangle {
        id: card
        anchors.fill: parent
        radius: 4 * skin.u
        color: skin.cream

        transform: [
            Tilt { target: card; amount: light.lightX; degrees: 7 },
            Tilt { target: card; amount: light.lightY; degrees: 7; vertical: true }
        ]

        Rectangle {
            x: (-20 + 30 * skin.slide) * skin.u + skin.drift
            width: 120 * skin.u
            height: card.height
            color: skin.red
        }
        Rectangle {
            x: (150 - 20 * skin.slide) * skin.u - skin.drift
            width: 100 * skin.u
            height: 120 * skin.u
            color: skin.blue
        }
        Rectangle {
            x: (150 - 20 * skin.slide) * skin.u - skin.drift * 0.6
            y: 120 * skin.u
            width: 100 * skin.u
            height: 130 * skin.u
            color: skin.mustard
        }
        Rectangle {
            y: 196 * skin.u
            width: card.width
            height: Math.max(2, 4 * skin.u)
            color: skin.ink
        }

        ClippingRectangle {
            x: 22 * skin.u
            y: 30 * skin.u
            width: 150 * skin.u
            height: width
            radius: 0
            visible: !skin.blankLabel
            color: skin.ink
            Image {
                anchors.fill: parent
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 400; height: 400 }
                asynchronous: true
                layer.enabled: true
                layer.effect: MultiEffect { saturation: -0.35; contrast: 0.2 }
            }
        }

        Text {
            x: 14 * skin.u
            y: 203 * skin.u
            visible: !skin.blankLabel
            text: skin.playing ? "SESSION #" + skin.session : "SEE YOU SPACE COWBOY..."
            color: skin.ink
            font {
                family: "sans-serif"
                pixelSize: Math.max(6, Math.round((skin.playing ? 13 : 12) * skin.u))
                weight: Font.Black
                letterSpacing: 1 * skin.u
            }
        }
        Text {
            x: 14 * skin.u
            y: 221 * skin.u
            width: 202 * skin.u
            visible: skin.playing && !skin.blankLabel
            text: skin.title.toUpperCase()
            elide: Text.ElideRight
            color: skin.ink
            font {
                family: "serif"
                pixelSize: Math.max(7, Math.round(15 * skin.u))
                weight: Font.Black
                italic: true
            }
        }
    }
}
