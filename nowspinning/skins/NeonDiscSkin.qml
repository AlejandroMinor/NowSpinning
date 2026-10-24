// Skin: a black disc with grooves lit in pink and cyan, synthwave style.
//
// The cover is its round label. It spins while playing, a bright stripe
// turning with it, and its pink halo breathes.
//
// Under the pointer the halo burns brighter and a sheen points at the
// pointer, the way the other discs catch the light.
//
// Round face, so the progress ring can go around it.
// The back, for the track info, is the disc without a label.
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
    property real spinDegreesPerSecond: 20
    property bool lightMotion: true   // the halo breathing
    property bool lightTilt: true     // the sheen turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color pink: "#ff2a6d"
    readonly property color cyan: "#00f0ff"

    // Room around the disc for the halo.
    readonly property real boxFactor: 1.08
    readonly property rect faceRect: Qt.rect((width - size) / 2, (height - size) / 2, size, size)
    readonly property bool faceIsCircle: true
    // It glows instead.
    readonly property bool ownShadow: true

    implicitWidth: Math.round(size * boxFactor)
    implicitHeight: implicitWidth

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

    property real breath: 0.6
    SequentialAnimation on breath {
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.6; duration: 1400; easing.type: Easing.InOutSine }
    }
    readonly property real glow: blankLabel ? 0.2 : (light.following ? 1 : breath)

    Rectangle {
        anchors.centerIn: parent
        width: skin.size
        height: skin.size
        radius: width / 2
        color: "#050507"
        border { width: Math.max(1.5, skin.size * 0.01); color: skin.pink }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: skin.pink
            shadowBlur: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: skin.glow
        }
    }

    Item {
        anchors.centerIn: parent
        width: skin.size
        height: skin.size
        rotation: spin.angle

        // Grooves, every third one cyan.
        Repeater {
            model: 14
            Rectangle {
                required property int index
                readonly property real d: skin.size * (0.93 - index * 0.04)
                anchors.centerIn: parent
                width: d
                height: d
                radius: d / 2
                color: "transparent"
                border {
                    width: 1
                    color: index % 3 === 0 ? Qt.rgba(0, 0.94, 1, 0.3 + 0.3 * skin.glow)
                                           : Qt.rgba(1, 0.16, 0.43, 0.12 + 0.12 * skin.glow)
                }
            }
        }

        // A bright stripe across it, turning with the disc.
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(2, skin.size * 0.016)
            height: skin.size * 0.9
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0.94, 1, 0.6) }
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(1, 0.16, 0.43, 0.6) }
            }
        }

        ClippingRectangle {
            anchors.centerIn: parent
            width: skin.size * 0.38
            height: width
            radius: width / 2
            color: "#111118"
            Image {
                anchors.fill: parent
                visible: !skin.blankLabel
                source: skin.blankLabel ? "" : skin.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 300; height: 300 }
                asynchronous: true
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(4, skin.size * 0.045)
            height: width
            radius: width / 2
            color: "#050507"
            border { width: 1; color: skin.cyan }
        }
    }

    // The sheen, pointing at the pointer. Doesn't spin.
    Item {
        anchors.centerIn: parent
        width: skin.size
        height: skin.size
        rotation: light.heading
        opacity: light.following ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Rectangle {
            x: (parent.width - width) / 2
            y: parent.height * 0.04
            width: skin.size * 0.05
            height: skin.size * 0.3
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }
}
