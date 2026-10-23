// One axis of a skin turning toward the light, for a `transform` list. Two
// of them, one `vertical`, turn it both ways. `amount` is LightDriver's
// lightX or lightY.
import QtQuick

Rotation {
    property Item target
    property real amount: 0
    property real degrees: 6
    property bool vertical: false

    origin.x: target ? target.width / 2 : 0
    origin.y: target ? target.height / 2 : 0
    axis { x: vertical ? 1 : 0; y: vertical ? 0 : 1; z: 0 }
    angle: amount * degrees * (vertical ? -1 : 1)
}
