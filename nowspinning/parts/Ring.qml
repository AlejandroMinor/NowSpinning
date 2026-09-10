// A solid ring: outer circle minus inner circle.
//
// Can't be done with a thick-bordered `Rectangle`: when the border is wider
// than the radius, Qt draws it with partial coverage and the fill ends up at
// ~86% opacity, letting whatever is behind it show through. A `Shape` with an
// odd-even fill rule gives a truly opaque ring instead.
import QtQuick
import QtQuick.Shapes

Shape {
    id: ring

    property real outerRadius: width / 2
    property real innerRadius: 0
    property color color: "black"

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: ring.color
        fillRule: ShapePath.OddEvenFill
        strokeColor: "transparent"
        strokeWidth: 0

        PathAngleArc {
            centerX: ring.width / 2
            centerY: ring.height / 2
            radiusX: ring.outerRadius
            radiusY: ring.outerRadius
            startAngle: 0
            sweepAngle: 360
            moveToStart: true
        }

        PathAngleArc {
            centerX: ring.width / 2
            centerY: ring.height / 2
            radiusX: ring.innerRadius
            radiusY: ring.innerRadius
            startAngle: 0
            sweepAngle: 360
            moveToStart: true
        }
    }
}
