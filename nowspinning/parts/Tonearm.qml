// A turntable's tonearm. Pivots just outside the disc's rim, upper right.
// Lowers onto the grooves while playing and walks inward with the track,
// the way a real needle follows the spiral; lifts to its rest when paused.
//
// The arm is rigid and swings around its pivot, so where the needle lands
// for a given angle comes from the law of cosines: with the pivot `d` disc
// radii from the center and an arm `l` long, putting the needle at radius
// `r` takes cos(a) = (r² - d² - l²) / (2·d·l), measured from the line back
// to the center. The default proportions come from measuring a screenshot
// of Spun, not from copying its code.
import QtQuick

Item {
    id: arm

    property real discSize: 170
    property bool down: false        // needle resting on the disc
    property real progress: 0        // 0..1 of the track

    // Geometry, in disc radii. The pivot's angle is in degrees, clockwise
    // from the right, like QML's own rotation.
    property real pivotDistance: 1.02
    property real pivotAngle: -38
    property real length: 0.97
    property real restRadius: 1.06   // needle while lifted: off the disc
    property real outerRadius: 0.94  // first groove
    property real innerRadius: 0.47  // last groove, just outside the label

    // The base plate around the bearing. Only reads right sitting on a
    // turntable's top plate; floating beside a bare disc it looks odd.
    property bool showBase: false
    property color baseRing: "#8c939b"

    property color metal: "#767b85"
    property color metalLight: "#53575f"
    property color metalDark: "#2f3238"

    readonly property real discRadius: discSize / 2
    readonly property real len: discRadius * length
    readonly property real tube: Math.max(2, discRadius * 0.038)

    // How much space it needs around the disc, as a multiple of the
    // diameter, with the default geometry.
    readonly property real boxFactor: 1.18

    // 0 = lifted, 1 = on the record. Animating this instead of the angle
    // keeps the track position live while the arm is coming down.
    property real drop: down ? 1 : 0
    Behavior on drop {
        NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
    }

    // Progress arrives in 100ms steps, and jumps on a seek or a new track:
    // this glides between them.
    property real trackRadius: outerRadius
        - (outerRadius - innerRadius) * Math.max(0, Math.min(1, progress))
    Behavior on trackRadius {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    readonly property real needleRadius:
        restRadius + (trackRadius - restRadius) * drop

    readonly property real swing: {
        const d = pivotDistance, l = length, r = needleRadius;
        const c = (r * r - d * d - l * l) / (2 * d * l);
        return pivotAngle + Math.acos(Math.max(-1, Math.min(1, c))) * 180 / Math.PI;
    }

    x: parent.width / 2 + discRadius * pivotDistance * Math.cos(pivotAngle * Math.PI / 180)
    y: parent.height / 2 + discRadius * pivotDistance * Math.sin(pivotAngle * Math.PI / 180)
    width: 0
    height: 0

    // Base plate, fixed to the deck: a dark collar with a metal ring.
    Rectangle {
        visible: arm.showBase
        anchors.centerIn: parent
        width: arm.discRadius * 0.40
        height: width
        radius: width / 2
        color: "#1b1e22"
        border.width: Math.max(1, arm.discRadius * 0.012)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        antialiasing: true

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.72
            height: width
            radius: width / 2
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(arm.baseRing, 1.25) }
                GradientStop { position: 1.0; color: Qt.darker(arm.baseRing, 1.6) }
            }
        }
    }

    Item {
        rotation: arm.swing

        // Contact shadow under the cartridge. Only exists while the needle
        // is actually on the disc: it's the one shadow that would really be
        // there.
        Rectangle {
            x: arm.len - arm.discRadius * 0.15
            y: arm.discRadius * 0.03
            width: arm.discRadius * 0.24
            height: arm.discRadius * 0.13
            radius: height / 2
            color: "black"
            antialiasing: true
            opacity: 0.34 * arm.drop
        }

        // Tube, with a short stub behind the pivot for the counterweight.
        Rectangle {
            x: -arm.discRadius * 0.24
            y: -arm.tube / 2
            width: arm.len + arm.discRadius * 0.24
            height: arm.tube
            radius: height / 2
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.00; color: arm.metal }
                GradientStop { position: 0.40; color: arm.metalLight }
                GradientStop { position: 1.00; color: arm.metalDark }
            }
        }

        // Counterweight: a knurled drum on the stub.
        Rectangle {
            id: weight
            x: -arm.discRadius * 0.38
            y: -height / 2
            width: arm.discRadius * 0.17
            height: arm.discRadius * 0.17
            radius: arm.discRadius * 0.025
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.00; color: "#3a4047" }
                GradientStop { position: 0.35; color: "#4a5158" }
                GradientStop { position: 1.00; color: "#1f2328" }
            }

            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: weight.width * (0.18 + index * 0.16)
                    y: weight.height * 0.08
                    width: Math.max(1, arm.discRadius * 0.008)
                    height: weight.height * 0.84
                    color: Qt.rgba(0, 0, 0, 0.35)
                }
            }
        }

        // Cartridge: the head that holds the needle. Aligned with the tube.
        Rectangle {
            id: head
            x: arm.len - arm.discRadius * 0.17
            y: -arm.discRadius * 0.055
            width: arm.discRadius * 0.20
            height: arm.discRadius * 0.11
            radius: arm.discRadius * 0.022
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.00; color: arm.metal }
                GradientStop { position: 0.45; color: arm.metalLight }
                GradientStop { position: 1.00; color: arm.metalDark }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: parent.height * 0.34
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.35)
                antialiasing: true
            }
        }

        // Finger lift, sticking out to the side of the head.
        Rectangle {
            x: head.x + head.width * 0.30
            y: head.y + head.height - 1
            width: Math.max(1.5, arm.discRadius * 0.03)
            height: arm.discRadius * 0.09
            radius: width / 2
            color: arm.metalLight
            antialiasing: true
        }

        // Needle.
        Rectangle {
            x: arm.len + arm.discRadius * 0.028
            y: -arm.discRadius * 0.008
            width: arm.discRadius * 0.045
            height: Math.max(1, arm.discRadius * 0.016)
            color: "#3a3d43"
            antialiasing: true
        }
    }

    // Pivot: a ring with a dark axle at the center, over the tube.
    Rectangle {
        anchors.centerIn: parent
        width: arm.discRadius * 0.17
        height: width
        radius: width / 2
        color: "#5c606a"
        border.width: Math.max(1, arm.discRadius * 0.012)
        border.color: arm.metalDark
        antialiasing: true
    }

    Rectangle {
        anchors.centerIn: parent
        width: arm.discRadius * 0.07
        height: width
        radius: width / 2
        color: "#212328"
        antialiasing: true
    }
}
