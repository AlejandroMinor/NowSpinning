// The face of a round disc: body, grooves, label, and center hole.
//
// This is the piece shared by every disc-based skin. A vinyl record and a CD
// are the same geometry with different numbers and colors, so everything
// that tells them apart is exposed as a property. Nothing is hard-coded
// in here.
//
// The body is drawn as a ring, not a filled circle: that way the center
// hole never gets painted, and the desktop shows through it.
//
// Drawn on a 1000x1000 canvas and scaled to the real size: that keeps the
// grooves sub-pixel, and the mipmapped layer smooths them out on the way
// down instead of turning into moire. The layer also caches the whole thing
// as a texture: it's drawn once, and after that only rotated.
import QtQuick

Item {
    id: face

    // Every measurement below lives on the 1000-unit canvas, i.e. they're
    // per-mille fractions of the diameter. `size` is the only thing in
    // actual pixels.
    property int size: 170

    property string artUrl: ""
    property real labelSize: 396          // label diameter
    property color labelPlaceholder: "#1c1c22"
    property int holeRadius: 16

    property color bodyColor: "#16171b"
    property color rimColor: "#24252a"
    property int rimWidth: 5

    property int grooveInner: 213
    property int grooveOuter: 488
    property int grooveStep: 4
    property color grooveLight: Qt.rgba(0.706, 0.725, 0.765, 0.047)
    property color grooveAccent: Qt.rgba(0.706, 0.725, 0.765, 0.102)
    property int grooveAccentEvery: 12
    property color grooveDark: Qt.rgba(0, 0, 0, 0.294)

    // Heavier bands, the kind that mark track boundaries on a real record.
    property var bandRadii: [242, 310, 381, 452]
    property color bandColor: Qt.rgba(0, 0, 0, 0.451)
    property int bandWidth: 3

    property color labelEdge: Qt.rgba(0, 0, 0, 0.471)
    property color labelInner: Qt.rgba(1, 1, 1, 0.125)
    property color holeEdge: Qt.rgba(0, 0, 0, 0.667)
    property color holeRim: Qt.rgba(1, 1, 1, 0.157)

    readonly property int canvas: 1000
    readonly property int grooveCount:
        Math.floor((grooveOuter - grooveInner) / grooveStep) + 1

    implicitWidth: size
    implicitHeight: size

    Item {
        id: plate

        width: face.canvas
        height: face.canvas
        anchors.centerIn: parent
        scale: face.size / face.canvas

        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true

        // Body.
        Ring {
            anchors.fill: parent
            outerRadius: 497
            innerRadius: face.holeRadius
            color: face.bodyColor
        }

        // Rim: the disc's edge catching a bit of light.
        Rectangle {
            anchors.centerIn: parent
            width: 994; height: 994
            radius: width / 2
            color: "transparent"
            border.width: face.rimWidth
            border.color: face.rimColor
            antialiasing: true
        }

        // Grooves. Each one is a pair: a light line and its shadow just
        // outside it. That pairing is what makes it read as a groove instead
        // of a gray haze.
        Item {
            anchors.fill: parent

            Repeater {
                model: face.grooveCount

                Item {
                    readonly property int grooveRadius: face.grooveInner + index * face.grooveStep
                    anchors.fill: parent

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.grooveRadius * 2; height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 0.85
                        border.color: parent.grooveRadius % face.grooveAccentEvery === 1
                            ? face.grooveAccent : face.grooveLight
                        antialiasing: true
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: (parent.grooveRadius + 1.5) * 2; height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: face.grooveDark
                        antialiasing: true
                    }
                }
            }

            Repeater {
                model: face.bandRadii

                Rectangle {
                    anchors.centerIn: parent
                    width: modelData * 2; height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: face.bandWidth
                    border.color: face.bandColor
                    antialiasing: true
                }
            }
        }

        ArtLabel {
            width: face.labelSize
            height: face.labelSize
            anchors.centerIn: parent
            artUrl: face.artUrl
            holeRadius: face.holeRadius
            placeholder: face.labelPlaceholder
        }

        Rectangle {
            anchors.centerIn: parent
            width: face.labelSize + 2; height: width
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: face.labelEdge
            antialiasing: true
        }

        Rectangle {
            anchors.centerIn: parent
            width: face.labelSize * 0.899; height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: face.labelInner
            antialiasing: true
        }

        // Center hole.
        Rectangle {
            anchors.centerIn: parent
            width: face.holeRadius * 2 + 4; height: width
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: face.holeEdge
            antialiasing: true
        }

        Rectangle {
            anchors.centerIn: parent
            width: face.holeRadius * 2 + 10; height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: face.holeRim
            antialiasing: true
        }
    }
}
