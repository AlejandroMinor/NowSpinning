// Skin: the cover in an art deco frame, black lacquer and gold.
//
// A double gold rule around the edge, a sunburst fan over the cover and the
// title in spaced capitals under it. While playing the fan's rays light up
// one after another, slowly; on each new track they open out. Under the
// pointer the frame turns toward it and a sheen runs across the gold.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the empty frame.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist` and `trackChangeToken`.
import QtQuick
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
    property bool lightMotion: true   // the rays lighting up on their own
    property bool lightTilt: true     // the frame turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color gold: "#d4af6a"
    readonly property color lacquer: "#0f0f12"

    implicitWidth: Math.round(size * 220 / 230)
    implicitHeight: Math.round(size * 250 / 230)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    readonly property real u: size / 230

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // Which ray is lit, running along the fan.
    property real sweep: -1
    NumberAnimation on sweep {
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        loops: Animation.Infinite
        from: -1
        to: 10
        duration: 3600
    }
    // How open the fan is, 0..1: it opens out on each new track.
    property real open: 1
    onTrackChangeTokenChanged: if (!blankLabel) opening.restart()
    NumberAnimation {
        id: opening
        target: skin
        property: "open"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutBack
    }

    Item {
        id: frame
        anchors.fill: parent

        transform: [
            Tilt { target: frame; amount: light.lightX; degrees: 7 },
            Tilt { target: frame; amount: light.lightY; degrees: 7; vertical: true }
        ]

        Rectangle {
            anchors.fill: parent
            color: skin.lacquer
            border { width: Math.max(1, 2 * skin.u); color: skin.gold }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 6 * skin.u
            color: "transparent"
            border { width: 1; color: skin.gold }
        }

        // The fan.
        Repeater {
            model: 9
            Rectangle {
                required property int index
                x: frame.width / 2
                y: 40 * skin.u
                width: Math.max(1, 1.2 * skin.u)
                height: 26 * skin.u
                transformOrigin: Item.Top
                rotation: 180 + (index - 4) * 16 * skin.open
                color: Math.abs(skin.sweep - index) < 1
                    ? Qt.lighter(skin.gold, 1.5) : skin.gold
                opacity: Math.abs(skin.sweep - index) < 1 ? 1 : 0.75
            }
        }
        Rectangle {
            x: frame.width / 2 - width / 2
            y: 32 * skin.u
            width: 28 * skin.u
            height: 14 * skin.u
            radius: height / 2
            color: skin.lacquer
            border { width: 1; color: skin.gold }
        }

        ClippingRectangle {
            x: (frame.width - width) / 2
            y: 50 * skin.u
            width: 150 * skin.u
            height: width
            color: "#1a1a1e"
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
            x: (frame.width - width) / 2
            y: 48 * skin.u
            width: 154 * skin.u
            height: width
            color: "transparent"
            border { width: 1; color: skin.gold }
        }

        Text {
            x: (frame.width - width) / 2
            y: 210 * skin.u
            width: 190 * skin.u
            visible: !skin.blankLabel
            horizontalAlignment: Text.AlignHCenter
            text: skin.title.toUpperCase().split("").join(" ")
            elide: Text.ElideRight
            color: skin.gold
            font { family: "serif"; pixelSize: Math.max(6, Math.round(10 * skin.u)); letterSpacing: 1 * skin.u }
        }
        Text {
            x: (frame.width - width) / 2
            y: 226 * skin.u
            width: 190 * skin.u
            visible: !skin.blankLabel && skin.artist !== ""
            horizontalAlignment: Text.AlignHCenter
            text: "— " + skin.artist + " —"
            elide: Text.ElideRight
            color: Qt.rgba(skin.gold.r, skin.gold.g, skin.gold.b, 0.7)
            font { family: "serif"; pixelSize: Math.max(5, Math.round(9 * skin.u)); italic: true }
        }

        // A sheen across the gold, following the light.
        Item {
            anchors.fill: parent
            clip: true
            opacity: light.following ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 260 } }
            Rectangle {
                width: frame.width * 0.35
                height: frame.height * 2
                x: frame.width * 0.32 + light.lightX * frame.width * 0.7
                y: -frame.height * 0.5
                rotation: 30
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 0.92, 0.7, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 0.92, 0.7, 0.16) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 0.92, 0.7, 0) }
                }
            }
        }
    }
}
