// A rectangle with its top-left and bottom-right corners cut off at 45
// degrees, the shape the cyberpunk skins are built from. Filled, outlined,
// or both.
import QtQuick
import QtQuick.Shapes

Shape {
    id: shape

    property real cut: 10
    property color fill: "white"
    property color stroke: "transparent"
    property real strokeWidth: 0

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: shape.fill
        strokeColor: shape.stroke
        strokeWidth: shape.strokeWidth
        joinStyle: ShapePath.MiterJoin
        PathPolyline {
            path: [Qt.point(shape.cut, 0), Qt.point(shape.width, 0),
                   Qt.point(shape.width, shape.height - shape.cut),
                   Qt.point(shape.width - shape.cut, shape.height),
                   Qt.point(0, shape.height), Qt.point(0, shape.cut),
                   Qt.point(shape.cut, 0)]
        }
    }
}
