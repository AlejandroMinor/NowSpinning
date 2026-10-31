// Skin: a 7" single, with the big center hole and a 45 adapter in it.
//
// The vinyl skin's record with a 7"'s numbers: a label half the disc wide,
// a band of grooves outside it, and the 38mm hole that the three-spoke
// adapter snaps into so it fits a regular spindle. The adapter takes the
// cover's color. Spins faster than the LP, the way 45 beats 33.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `accent`, `progress` and `showArm`.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property real progress: 0
    property color accent: "white"
    property bool showArm: false
    property bool blankLabel: false
    // The sheen turning with the pointer. Room light doesn't drift on its
    // own, so there's no lightMotion here.
    property bool lightTilt: true

    property real spinDegreesPerSecond: 13

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property real boxFactor: showArm ? arm.boxFactor : 1.02
    readonly property rect faceRect: Qt.rect((width - size) / 2, (height - size) / 2, size, size)
    readonly property bool faceIsCircle: true

    implicitWidth: Math.round(size * boxFactor)
    implicitHeight: implicitWidth

    readonly property bool tinted: !Qt.colorEqual(accent, "white")
    readonly property color adapterColor: tinted ? accent : "#e8b630"

    // On DiscFace's 1000-unit canvas: 38mm hole and 89mm label on a 175mm disc.
    readonly property int hole: 108
    readonly property int label: 508

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

    Item {
        anchors.centerIn: parent
        width: skin.size
        height: skin.size

        DiscFace {
            id: disc
            anchors.centerIn: parent
            size: skin.size
            artUrl: skin.blankLabel ? "" : skin.artUrl
            rotation: spin.angle
            labelSize: skin.blankLabel ? 760 : skin.label
            holeRadius: skin.hole
            grooveInner: 272
            grooveOuter: 488
            grooveStep: 4
            bandRadii: [330, 410]
        }

        // The 45 adapter: a ring that fills the hole, three spokes, and a
        // small hub that takes the spindle. It turns with the record.
        Item {
            anchors.centerIn: parent
            width: skin.size * skin.hole * 2 / 1000
            height: width
            rotation: spin.angle

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1.5, parent.width * 0.09)
                border.color: skin.adapterColor
                antialiasing: true
            }

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * 0.16
                    height: parent.height * 0.92
                    radius: width / 2
                    color: skin.adapterColor
                    rotation: index * 60
                    antialiasing: true
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.34
                height: width
                radius: width / 2
                color: Qt.darker(skin.adapterColor, 1.15)
                antialiasing: true

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.32
                    height: width
                    radius: width / 2
                    color: "#15161a"
                }
            }
        }

        Sheen {
            anchors.fill: parent
            holeRadius: skin.size * skin.hole / 1000
            startAngle: 24
            following: light.following
            heading: light.heading
        }

        Tonearm {
            id: arm
            visible: skin.showArm
            discSize: skin.size
            // Hidden, it follows nothing: its glides would run every frame
            // for no one. Shown again, it drops onto the record and glides
            // to the track, as on play.
            down: skin.playing && visible
            progress: visible ? skin.progress : 0
            // The grooves stop at the label's edge, which sits much further
            // out than on an LP.
            innerRadius: 0.60
            z: 1
        }
    }
}
