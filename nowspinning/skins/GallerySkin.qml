// Skin: the cover hung in a gallery, a thin black frame around a wide white
// mat, with a brass plaque under it for the title and artist.
//
// A light from above falls on it while playing and dims when paused. Under
// the pointer the frame turns toward it a little and the light follows the
// pointer across the mat, like someone stepping up with a torch.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the empty mat.
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
    property bool lightTilt: true     // the frame turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // The frame, its shadow on the wall and the plaque under it.
    readonly property real frameSide: Math.round(size * 0.92)
    readonly property real margin: size * 0.04

    implicitWidth: Math.round(frameSide + 2 * margin)
    implicitHeight: Math.round(frameSide * 1.24 + 2 * margin)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(margin, margin, frameSide, frameSide)
    readonly property bool faceIsCircle: false
    // The frame casts its own, on the wall.
    readonly property bool ownShadow: true

    readonly property real u: frameSide / 210

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    readonly property real lamp: blankLabel ? 0.03
        : light.following ? 0.3 : (playing ? 0.2 : 0.04)
    property real lit: lamp
    Behavior on lit { NumberAnimation { duration: 600 } }

    Item {
        id: hung
        x: skin.margin
        y: skin.margin
        width: skin.frameSide
        height: skin.frameSide * 1.24

        transform: [
            Tilt { target: hung; amount: light.lightX; degrees: 4 },
            Tilt { target: hung; amount: light.lightY; degrees: 4; vertical: true }
        ]

        Rectangle {
            id: frame
            width: skin.frameSide
            height: skin.frameSide
            color: "#151515"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowBlur: 0.7
                shadowVerticalOffset: 6 * skin.u
                shadowOpacity: 0.6
            }

            Rectangle {
                id: mat
                anchors.fill: parent
                anchors.margins: 7 * skin.u
                color: "#f4f1ea"

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 130 * skin.u
                    height: width
                    color: "#e3dfd5"
                    Image {
                        anchors.fill: parent
                        visible: !skin.blankLabel
                        source: skin.blankLabel ? "" : skin.artUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize { width: 400; height: 400 }
                        asynchronous: true
                    }
                }

                // The light: a warm pool from above, or wherever the pointer
                // holds the torch.
                Item {
                    anchors.fill: parent
                    clip: true
                    Rectangle {
                        readonly property real d: mat.width * 1.6
                        width: d
                        height: d
                        radius: d / 2
                        x: mat.width / 2 - d / 2 + light.lightX * mat.width * 0.4
                        y: -d * 0.55 + (light.following ? (light.lightY + 1) * mat.height * 0.35 : 0)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 0.96, 0.85, skin.lit) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 0.96, 0.85, 0) }
                        }
                    }
                    // Unlit, the room is dim.
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.18 * (1 - skin.lit / 0.3))
                    }
                }
            }
        }

        // The plaque.
        Rectangle {
            x: (skin.frameSide - width) / 2
            y: skin.frameSide + 12 * skin.u
            width: 150 * skin.u
            height: 34 * skin.u
            radius: 2 * skin.u
            visible: !skin.blankLabel
            gradient: Gradient {
                GradientStop { position: 0; color: "#c9a96a" }
                GradientStop { position: 1; color: "#8f733f" }
            }
            Text {
                x: 5 * skin.u
                y: 4 * skin.u
                width: parent.width - 10 * skin.u
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: skin.title
                color: "#2a2010"
                font { family: "serif"; pixelSize: Math.max(6, Math.round(11 * skin.u)); italic: true; weight: Font.DemiBold }
            }
            Text {
                x: 5 * skin.u
                y: 19 * skin.u
                width: parent.width - 10 * skin.u
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: skin.artist
                color: "#3d301a"
                font { family: "serif"; pixelSize: Math.max(5, Math.round(9 * skin.u)) }
            }
        }
    }
}
