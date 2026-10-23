// A white glint across a surface, slid along by the light: the foil card's,
// for anything else that should catch it the same way. Fills its parent and
// clips to its box. `lightX` is LightDriver's.
import QtQuick

Item {
    id: glint

    property real lightX: 0
    property real strength: 0.28

    anchors.fill: parent
    clip: true

    Rectangle {
        width: glint.width * 0.25
        height: glint.height * 3
        x: glint.width * 0.38 + glint.lightX * glint.width * 0.7
        y: -glint.height
        rotation: 32
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, glint.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
