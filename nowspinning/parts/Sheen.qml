// The disc's light sheen. Lives outside whatever is spinning: room light
// doesn't spin with the disc, it stays fixed relative to the screen.
//
// Conical, because on a disc the light sweeps at an angle, not in a straight
// line. The mask is a ring so the sheen never paints over the center hole.
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: sheen

    property real holeRadius: 0     // in pixels, not in the 1000-unit canvas
    property int startAngle: 24

    property Gradient sweep: Gradient {
        GradientStop { position: 0.00; color: Qt.rgba(0.75, 0.79, 0.85, 0.00) }
        GradientStop { position: 0.12; color: Qt.rgba(0.75, 0.79, 0.85, 0.09) }
        GradientStop { position: 0.22; color: Qt.rgba(0.75, 0.79, 0.85, 0.00) }
        GradientStop { position: 0.50; color: Qt.rgba(1.00, 0.92, 0.80, 0.00) }
        GradientStop { position: 0.63; color: Qt.rgba(1.00, 0.92, 0.80, 0.07) }
        GradientStop { position: 0.73; color: Qt.rgba(1.00, 0.92, 0.80, 0.00) }
        GradientStop { position: 1.00; color: Qt.rgba(0.75, 0.79, 0.85, 0.00) }
    }

    Ring {
        id: mask
        anchors.fill: parent
        outerRadius: width / 2
        innerRadius: sheen.holeRadius
        color: "black"
        visible: false
        layer.enabled: true
    }

    ConicalGradient {
        anchors.fill: parent
        angle: sheen.startAngle
        source: mask
        cached: true
        gradient: sheen.sweep
    }
}
