// Skin: the cover framed by a pink neon tube, with the title lit in cyan
// underneath, like a sign on a wet street.
//
// The tube flickers when playback starts and now and then while playing,
// and burns low while paused.
//
// Under the pointer the sign turns toward it and the tube burns brighter.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the sign switched off.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title` and `artist`.
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
    property string artist: ""
    property bool blankLabel: false
    property bool lightMotion: true   // the flicker now and then
    property bool lightTilt: true     // the sign turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color pink: "#ff2a6d"
    readonly property color cyan: "#00f0ff"

    // The tube's square, the lettering under it, and room for the glow.
    readonly property real tube: Math.round(size * 0.84)
    readonly property real margin: (size - tube) / 2
    readonly property real letters: Math.round(size * 0.26)

    implicitWidth: size
    implicitHeight: Math.round(tube + letters + 2 * margin)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(margin, margin, tube, tube + letters)
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

    // How hard the tube burns, 0..1. Low while paused, off on the back.
    readonly property real level: blankLabel ? 0.08
        : light.following ? 1 : (playing ? 0.85 : 0.45)
    property real steady: level
    Behavior on steady { NumberAnimation { duration: 300 } }
    // Cut by a flicker now and then.
    property real flick: 1
    readonly property real power: steady * flick

    // A flicker: the tube catching, cutting out and catching again.
    function flicker() {
        if (!blankLabel && !flickerAnim.running)
            flickerAnim.start();
    }
    onPlayingChanged: if (playing) flicker()
    SequentialAnimation {
        id: flickerAnim
        NumberAnimation { target: skin; property: "flick"; to: 0.15; duration: 30 }
        NumberAnimation { target: skin; property: "flick"; to: 1; duration: 40 }
        PauseAnimation { duration: 90 }
        NumberAnimation { target: skin; property: "flick"; to: 0.3; duration: 30 }
        NumberAnimation { target: skin; property: "flick"; to: 1; duration: 60 }
    }
    Timer {
        interval: 5200
        repeat: true
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        onTriggered: skin.flicker()
    }

    Item {
        id: sign
        x: skin.margin
        y: skin.margin
        width: skin.tube
        height: skin.tube + skin.letters

        transform: [
            Tilt { target: sign; amount: light.lightX; degrees: 8 },
            Tilt { target: sign; amount: light.lightY; degrees: 8; vertical: true }
        ]

        ClippingRectangle {
            anchors.fill: tubeRing
            anchors.margins: tubeRing.border.width + skin.tube * 0.025
            radius: tubeRing.radius * 0.7
            color: "#0b0b10"
            Image {
                anchors.fill: parent
                visible: !skin.blankLabel
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 400; height: 400 }
                asynchronous: true
            }
        }

        Rectangle {
            id: tubeRing
            width: skin.tube
            height: skin.tube
            radius: skin.tube * 0.11
            color: "transparent"
            border { width: Math.max(2, skin.tube * 0.022); color: Qt.lighter(skin.pink, 1.35) }
            opacity: 0.35 + 0.65 * skin.power
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.pink
                shadowBlur: 1
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowOpacity: skin.power
            }
        }

        Text {
            id: lit
            y: skin.tube + skin.letters * 0.12
            width: skin.tube
            horizontalAlignment: Text.AlignHCenter
            text: skin.blankLabel ? "" : skin.title
            elide: Text.ElideRight
            color: "#d9fdff"
            font { family: "monospace"; pixelSize: Math.max(8, Math.round(skin.size * 0.1)); weight: Font.Bold }
            opacity: 0.45 + 0.55 * skin.power
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.cyan
                shadowBlur: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowOpacity: skin.power
            }
        }

        Text {
            anchors.top: lit.bottom
            anchors.topMargin: skin.letters * 0.04
            width: skin.tube
            horizontalAlignment: Text.AlignHCenter
            visible: !skin.blankLabel
            text: skin.artist
            elide: Text.ElideRight
            color: Qt.rgba(1, 0.6, 0.75, 0.85)
            font { family: "monospace"; pixelSize: Math.max(6, Math.round(skin.size * 0.055)) }
        }
    }
}
