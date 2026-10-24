// Skin: the track on the cover of a music magazine.
//
// The cover art fills it, under a big serif NOW masthead and an issue
// number per track; the artist runs in yellow capitals at the bottom, the
// title in quotes under it, and a cover line points to the interview.
// Each new track is a new issue, sliding in over the last. Paused, the
// issue fades a little, like one left on the stand.
//
// Under the pointer the magazine turns toward it and its corner lifts, as
// if about to turn the page.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the bare cover.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist` and `trackChangeToken`.
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
    property int trackChangeToken: 0
    property bool blankLabel: false
    property bool lightTilt: true     // the magazine turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    implicitWidth: Math.round(size * 0.95)
    implicitHeight: Math.round(implicitWidth * 1.35)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Laid out on a 200 x 270 grid, scaled to the size.
    readonly property real u: implicitWidth / 200

    function hash(s, m) {
        let n = 0;
        for (let i = 0; i < s.length; i++)
            n = (n * 31 + s.charCodeAt(i)) % m;
        return n;
    }
    readonly property int issue: hash(title, 50) + 1
    readonly property int page: hash(artist + title, 90) + 10

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // The corner lifting under the pointer, 0..1.
    property real curl: light.following ? 1 : 0
    Behavior on curl { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // A new issue slides in from the right.
    property real arrive: 0
    onTrackChangeTokenChanged: if (!blankLabel) arriving.restart()
    NumberAnimation {
        id: arriving
        target: skin
        property: "arrive"
        from: 1
        to: 0
        duration: 520
        easing.type: Easing.OutCubic
    }

    Item {
        id: mag
        anchors.fill: parent

        transform: [
            Tilt { target: mag; amount: light.lightX; degrees: 8 },
            Tilt { target: mag; amount: light.lightY; degrees: 8; vertical: true }
        ]

        ClippingRectangle {
            id: page
            anchors.fill: parent
            radius: 2 * skin.u
            color: "#1a1a1a"

            Item {
                anchors.fill: parent
                x: skin.arrive * skin.width
                opacity: 1 - skin.arrive * 0.6

                Image {
                    anchors.fill: parent
                    visible: !skin.blankLabel
                    source: skin.blankLabel ? "" : skin.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize { width: 500; height: 500 }
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect { saturation: skin.playing ? 0 : -0.5 }
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.55; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                    }
                }

                // Shrinks to leave the issue number its corner, whatever
                // serif the system picks.
                Text {
                    x: 10 * skin.u
                    y: 2 * skin.u
                    width: 128 * skin.u
                    fontSizeMode: Text.HorizontalFit
                    text: "NOW"
                    color: "white"
                    font { family: "serif"; pixelSize: Math.max(12, Math.round(50 * skin.u)); weight: Font.Black; letterSpacing: -2 * skin.u }
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.4; shadowOpacity: 0.5 }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10 * skin.u
                    y: 12 * skin.u
                    visible: !skin.blankLabel
                    text: "ISSUE\nNo. " + skin.issue
                    horizontalAlignment: Text.AlignRight
                    lineHeight: 0.9
                    color: "white"
                    font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(9 * skin.u)); weight: Font.Bold }
                }
                Text {
                    x: 12 * skin.u
                    y: 196 * skin.u
                    width: parent.width - 24 * skin.u
                    visible: !skin.blankLabel
                    text: skin.artist.toUpperCase()
                    elide: Text.ElideRight
                    color: "#ffd23f"
                    font { family: "sans-serif"; pixelSize: Math.max(7, Math.round(22 * skin.u)); weight: Font.Black }
                }
                Text {
                    x: 12 * skin.u
                    y: 224 * skin.u
                    width: parent.width - 24 * skin.u
                    visible: !skin.blankLabel
                    text: "“" + skin.title + "”"
                    elide: Text.ElideRight
                    color: "white"
                    font { family: "serif"; pixelSize: Math.max(6, Math.round(13 * skin.u)); italic: true }
                }
                Text {
                    x: 12 * skin.u
                    y: 246 * skin.u
                    visible: !skin.blankLabel
                    text: "THE INTERVIEW · PAGE " + skin.page
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(8 * skin.u)); weight: Font.Bold; letterSpacing: 1 * skin.u }
                }
            }

            // The lifted corner: the back of the page, folded over.
            Shape {
                readonly property real c: skin.curl * 34 * skin.u
                visible: c > 0.5
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: "#f2efe8"
                    startX: page.width - parent.c; startY: page.height
                    PathLine { x: page.width; y: page.height - parent.c }
                    PathLine { x: page.width - parent.c; y: page.height - parent.c }
                    PathLine { x: page.width - parent.c; y: page.height }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowOpacity: 0.5
                    shadowBlur: 0.3
                    shadowHorizontalOffset: -2 * skin.u
                    shadowVerticalOffset: -2 * skin.u
                }
            }
        }
    }
}
