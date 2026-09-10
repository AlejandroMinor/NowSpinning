// A turntable's tonearm. Pivots just outside the disc's rim, upper right.
// Lowers onto the grooves while playing; lifts to its rest when paused.
//
// The two angles come from the law of cosines: with the pivot at 1.02 times
// discRadius from the center and a rigid arm 0.97 * discRadius long, 100
// degrees puts the needle at 0.71 * discRadius (groove territory) and 78
// puts it at 1.06 * discRadius (off the disc). The proportions come from
// measuring a screenshot of Spun, not from copying its code.
import QtQuick

Item {
    id: arm

    property real discSize: 170
    property bool down: false        // needle resting on the disc

    property color metal: "#767b85"
    property color metalLight: "#53575f"
    property color metalDark: "#2f3238"

    readonly property real discRadius: discSize / 2
    readonly property real len: discRadius * 0.97
    readonly property real tube: Math.max(2, discRadius * 0.038)

    // How much space it needs around the disc, as a multiple of the diameter.
    readonly property real boxFactor: 1.18

    // Pivot: disc center + (0.804, -0.628) * discRadius, i.e. almost
    // touching the rim.
    x: parent.width / 2 + discRadius * 0.804
    y: parent.height / 2 - discRadius * 0.628
    width: 0
    height: 0

    rotation: down ? 100 : 78
    Behavior on rotation {
        NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
    }

    // Contact shadow under the cartridge. Only exists while the needle is
    // actually on the disc: it's the one shadow that would really be there.
    Rectangle {
        x: arm.discRadius * 0.82
        y: arm.discRadius * 0.03
        width: arm.discRadius * 0.24
        height: arm.discRadius * 0.13
        radius: height / 2
        color: "black"
        antialiasing: true
        opacity: arm.down ? 0.34 : 0
        Behavior on opacity { NumberAnimation { duration: 900 } }
    }

    // Tube.
    Rectangle {
        x: 0
        y: -arm.tube / 2
        width: arm.len
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

    // Cartridge: the head that holds the needle. Aligned with the tube.
    Rectangle {
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

    // Needle.
    Rectangle {
        x: arm.len + arm.discRadius * 0.028
        y: -arm.discRadius * 0.008
        width: arm.discRadius * 0.045
        height: Math.max(1, arm.discRadius * 0.016)
        color: "#3a3d43"
        antialiasing: true
    }

    // Pivot: a ring with a dark axle at the center.
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
