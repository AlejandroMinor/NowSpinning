// Skin: the cover on a hard-bop jazz sleeve.
//
// The top of the sleeve is the cover in duotone, the bottom a block of the
// same colour with the artist in big bold capitals and the title under it.
// The colour is the cover's own (sleeveColor "art"), or one from a short
// palette of the label's era, the same one for the same track ("palette",
// and the fallback for a cover with no real colour in it), or any
// "#rrggbb". The
// record sits inside: while playing it peeks out of the sleeve, spinning;
// under the pointer it slides further out and the sleeve turns toward it.
//
// Rectangular face (the sleeve), so the window swaps the ring for the bar
// on its own. The back, for the track info, is the plain sleeve.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title` and `artist`.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import ".."
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property string artist: ""
    property bool blankLabel: false
    property real spinDegreesPerSecond: 30
    property bool lightTilt: true     // the sleeve turning toward the pointer
    property string sleeveColor: "art"  // art | palette | "#rrggbb"

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // The sleeve, and room on its right for the record to come out.
    readonly property real sleeve: Math.round(size * 0.9)
    readonly property real disc: sleeve * 0.94

    implicitWidth: Math.round(sleeve + disc * 0.46)
    implicitHeight: sleeve

    readonly property real boxFactor: implicitWidth / size
    readonly property rect faceRect: Qt.rect(0, 0, sleeve, sleeve)
    readonly property bool faceIsCircle: false

    readonly property real u: sleeve / 230

    readonly property var palette: ["#2d7fd3", "#e0702a", "#2f9e6e", "#c8323a", "#1d9aa6", "#7a4cc2"]
    ArtAccent {
        id: artColor
        source: skin.artUrl
        enabled: skin.sleeveColor === "art" && !skin.blankLabel
    }

    readonly property color tone: {
        if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(sleeveColor))
            return sleeveColor;
        // The cover's colour, deep enough for the white lettering on it.
        if (sleeveColor === "art" && artColor.tinted)
            return Qt.hsla(artColor.accent.hslHue, Math.max(0.5, artColor.accent.hslSaturation), 0.46, 1);
        let n = 0;
        for (let i = 0; i < title.length; i++)
            n = (n * 31 + title.charCodeAt(i)) % palette.length;
        return palette[n];
    }

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    SpinDriver {
        id: spin
        playing: skin.playing
        degreesPerSecond: skin.spinDegreesPerSecond
    }

    // How far out of the sleeve the record is, as a share of its width.
    readonly property real out: blankLabel ? 0
        : light.following ? 0.44
        : playing ? 0.24 : 0.06
    property real peek: out
    Behavior on peek { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

    // The record, behind the sleeve.
    Item {
        x: (skin.sleeve - skin.disc) / 2 + skin.peek * skin.disc
        y: (skin.sleeve - skin.disc) / 2
        width: skin.disc
        height: skin.disc
        rotation: spin.angle

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#0c0c0c"
            border { width: 1; color: "#2a2a2a" }
        }
        Repeater {
            model: 8
            Rectangle {
                required property int index
                readonly property real d: skin.disc * (0.92 - index * 0.06)
                anchors.centerIn: parent
                width: d
                height: d
                radius: d / 2
                color: "transparent"
                border { width: 1; color: Qt.rgba(1, 1, 1, 0.05) }
            }
        }
        ClippingRectangle {
            anchors.centerIn: parent
            width: skin.disc * 0.36
            height: width
            radius: width / 2
            color: skin.tone
            Image {
                anchors.fill: parent
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 200; height: 200 }
                asynchronous: true
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(3, skin.disc * 0.03)
            height: width
            radius: width / 2
            color: "#0c0c0c"
        }
    }

    Item {
        id: cover
        width: skin.sleeve
        height: skin.sleeve

        transform: [
            Tilt { target: cover; amount: light.lightX; degrees: 7 },
            Tilt { target: cover; amount: light.lightY; degrees: 7; vertical: true }
        ]

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.45
            shadowBlur: 0.4
            shadowHorizontalOffset: 3
            shadowVerticalOffset: 0
        }

        Rectangle { anchors.fill: parent; color: "#0d0d0d" }
        Item {
            width: parent.width
            height: 150 * skin.u
            clip: true
            visible: !skin.blankLabel
            Image {
                anchors.fill: parent
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 400; height: 400 }
                asynchronous: true
                layer.enabled: true
                layer.effect: MultiEffect { colorization: 1; colorizationColor: skin.tone; contrast: 0.35 }
            }
        }
        Rectangle {
            y: 150 * skin.u
            width: parent.width
            height: parent.height - y
            color: skin.tone
        }
        Text {
            x: 12 * skin.u
            y: 155 * skin.u
            width: parent.width - 24 * skin.u
            visible: !skin.blankLabel
            text: skin.artist.toUpperCase()
            elide: Text.ElideRight
            color: "white"
            font { family: "sans-serif"; pixelSize: Math.max(8, Math.round(26 * skin.u)); weight: Font.Black; letterSpacing: -1 * skin.u }
        }
        Text {
            x: 12 * skin.u
            y: 191 * skin.u
            width: parent.width - 24 * skin.u
            visible: !skin.blankLabel
            text: skin.title
            elide: Text.ElideRight
            color: "#0d0d0d"
            font { family: "sans-serif"; pixelSize: Math.max(6, Math.round(15 * skin.u)); weight: Font.DemiBold; italic: true }
        }
    }
}
