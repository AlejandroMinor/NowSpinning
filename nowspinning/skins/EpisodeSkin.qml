// Skin: the track as an anime episode title card.
//
// White heavy serif on black, set the way a certain 90s mecha show set its
// episode titles: EPISODE and a number up top, the artist big under it, the
// title running down the right edge a letter a line, and again in italics
// at the bottom. While playing it cuts, hard, between the card and the
// cover every few seconds. Paused, the card holds, with TO BE CONTINUED.
//
// Under the pointer the card turns toward it and cuts to the cover.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the black card.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist` and `trackChangeToken`.
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
    property int trackChangeToken: 0
    property bool blankLabel: false
    property bool lightMotion: true   // the cuts on their own
    property bool lightTilt: true     // the card turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    implicitWidth: size
    implicitHeight: size

    readonly property real boxFactor: 1
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Laid out on a 220 x 220 grid, scaled to the size.
    readonly property real u: size / 220

    readonly property int episode: {
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

    // Which is up: the card (false) or the cover (true).
    property bool cut: false
    readonly property bool showingArt: !blankLabel && (light.following || cut)
    Timer {
        interval: 2600
        repeat: true
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        onTriggered: skin.cut = !skin.cut
        onRunningChanged: if (!running) skin.cut = false
    }
    // A new track opens on its card.
    onTrackChangeTokenChanged: cut = false

    ClippingRectangle {
        id: card
        anchors.fill: parent
        color: "black"
        radius: 2 * skin.u

        transform: [
            Tilt { target: card; amount: light.lightX; degrees: 7 },
            Tilt { target: card; amount: light.lightY; degrees: 7; vertical: true }
        ]

        // Hard cuts: no fade, the way the show did it.
        Image {
            anchors.fill: parent
            visible: skin.showingArt
            source: skin.blankLabel ? "" : skin.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize { width: 400; height: 400 }
            asynchronous: true
            layer.enabled: true
            layer.effect: MultiEffect { saturation: -0.3; contrast: 0.25 }
        }

        Item {
            anchors.fill: parent
            visible: !skin.showingArt && !skin.blankLabel

            Text {
                x: 14 * skin.u
                y: 14 * skin.u
                text: "EPISODE:" + String(skin.episode).padStart(2, "0")
                color: "white"
                font { family: "serif"; pixelSize: Math.max(6, Math.round(15 * skin.u)); weight: Font.Black }
            }
            Text {
                x: 14 * skin.u
                y: 40 * skin.u
                width: 172 * skin.u
                text: skin.artist.toUpperCase()
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                lineHeight: 0.9
                color: "white"
                font { family: "serif"; pixelSize: Math.max(10, Math.round(30 * skin.u)); weight: Font.Black; letterSpacing: -1 * skin.u }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14 * skin.u
                y: 118 * skin.u
                text: skin.title.toUpperCase().replace(/\s+/g, "").slice(0, 7).split("").join("\n")
                lineHeight: 0.82
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font { family: "serif"; pixelSize: Math.max(6, Math.round(14 * skin.u)); weight: Font.Black }
            }
            Text {
                x: 14 * skin.u
                y: (skin.playing ? 182 : 168) * skin.u
                width: 160 * skin.u
                text: skin.title
                elide: Text.ElideRight
                color: "white"
                font { family: "serif"; pixelSize: Math.max(6, Math.round(12 * skin.u)); weight: Font.Bold; italic: true }
            }
            Text {
                x: 14 * skin.u
                y: 188 * skin.u
                visible: !skin.playing
                text: "TO BE CONTINUED"
                color: "white"
                font { family: "serif"; pixelSize: Math.max(5, Math.round(10 * skin.u)); weight: Font.Black; letterSpacing: 2 * skin.u }
            }
        }
    }
}
