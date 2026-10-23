// The turntable under the record: the plinth, the platter, and the bits of
// hardware on its top plate (speed keys, cue lever, lid hinges).
//
// Seen from straight above, so it's all flat shapes and gradients. The
// layout follows Spun's 3D turntable (qml/Vinyl3D.qml) as a visual
// reference: platter off-center to the left, arm and cue on the right,
// speed keys at the front left. None of its code lives here.
//
// Fills its parent. Everything is placed relative to the disc's center
// (`cx`, `cy`) in disc radii, so the skin decides where the disc goes and
// how much plinth sits around it.
import QtQuick
import QtQuick.Effects

Item {
    id: deck

    property real discSize: 170
    property real cx: width / 2
    property real cy: height / 2

    // Plinth edges, in disc radii from the disc's center.
    property real edgeLeft: 1.20
    property real edgeRight: 1.56
    property real edgeTop: 1.36
    property real edgeBottom: 1.20

    property real platterRadius: 1.06
    property real angle: 0           // the record's spin, for the strobe dots
    property bool playing: false
    property color accent: "white"

    // Where the cue lever sits, in disc radii from the center.
    property point cue: Qt.point(1.40, -0.42)

    readonly property real r: discSize / 2
    readonly property bool tinted: !Qt.colorEqual(accent, "white")

    // The platter's metal picks up a little of the cover art's color.
    readonly property color platterMetal: tinted
        ? Qt.tint("#8c939b", Qt.rgba(accent.r, accent.g, accent.b, 0.35))
        : "#8c939b"

    // Plinth. Static, so the shadow is rendered once into the layer.
    Rectangle {
        id: plinth
        x: deck.cx - deck.edgeLeft * deck.r
        y: deck.cy - deck.edgeTop * deck.r
        width: (deck.edgeLeft + deck.edgeRight) * deck.r
        height: (deck.edgeTop + deck.edgeBottom) * deck.r
        radius: deck.r * 0.08
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2b2f34" }
            GradientStop { position: 1.0; color: "#1c1f23" }
        }
        border.width: Math.max(1, deck.r * 0.01)
        border.color: Qt.rgba(1, 1, 1, 0.07)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.55
            shadowBlur: 0.6
            shadowVerticalOffset: deck.r * 0.04
        }

        // Seam between the enclosure and the top plate.
        Rectangle {
            anchors.fill: parent
            anchors.margins: deck.r * 0.035
            radius: plinth.radius * 0.6
            color: "transparent"
            border.width: Math.max(1, deck.r * 0.008)
            border.color: Qt.rgba(0, 0, 0, 0.35)
            antialiasing: true
        }

        // Dust cover hinges, along the back edge.
        Repeater {
            model: [-0.75, 0.45]
            Rectangle {
                required property real modelData
                x: deck.edgeLeft * deck.r + modelData * deck.r - width / 2
                y: -height * 0.35
                width: deck.r * 0.26
                height: deck.r * 0.09
                radius: deck.r * 0.02
                color: "#15171a"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)
                antialiasing: true
            }
        }
    }

    // Platter: a metal ring around the record, with strobe dots on its rim
    // that turn with it.
    Rectangle {
        id: platter
        x: deck.cx - width / 2
        y: deck.cy - height / 2
        width: deck.platterRadius * deck.r * 2
        height: width
        radius: width / 2
        antialiasing: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Qt.darker(deck.platterMetal, 1.5) }
            GradientStop { position: 0.35; color: Qt.lighter(deck.platterMetal, 1.15) }
            GradientStop { position: 0.65; color: deck.platterMetal }
            GradientStop { position: 1.00; color: Qt.darker(deck.platterMetal, 1.8) }
        }

        // Thin steel lip on the very edge.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, deck.r * 0.008)
            border.color: Qt.rgba(1, 1, 1, 0.22)
            antialiasing: true
        }

        Item {
            anchors.fill: parent
            rotation: deck.angle
            layer.enabled: true
            layer.smooth: true

            Repeater {
                model: 48
                Rectangle {
                    required property int index
                    width: Math.max(1, deck.r * 0.018)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.45)
                    antialiasing: true
                    readonly property real a: index * Math.PI * 2 / 48
                    readonly property real rr: (deck.platterRadius - 0.022) * deck.r
                    x: platter.width / 2 + rr * Math.cos(a) - width / 2
                    y: platter.height / 2 + rr * Math.sin(a) - height / 2
                }
            }
        }

        // Rubber mat, just wider than the record.
        Rectangle {
            anchors.centerIn: parent
            width: deck.r * 2.04
            height: width
            radius: width / 2
            color: "#121417"
            antialiasing: true
        }
    }

    // Speed keys, front left. 33⅓ is the only speed there is, so its light
    // is the one that's on while playing.
    Repeater {
        model: ["33", "45"]
        Item {
            id: key
            required property int index
            required property string modelData
            readonly property real size: deck.r * 0.15
            x: deck.cx + (-1.02 + index * 0.24) * deck.r - size / 2
            y: deck.cy + 1.04 * deck.r - size / 2
            width: size
            height: size

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#4b5259" }
                    GradientStop { position: 1.0; color: "#25292e" }
                }
                border.width: Math.max(1, deck.r * 0.01)
                border.color: "#121417"
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: deck.r * 0.025
                width: Math.max(2, deck.r * 0.03)
                height: width
                radius: width / 2
                antialiasing: true
                color: key.index === 0 && deck.playing
                    ? (deck.tinted ? deck.accent : "#e8c47a") : "#3a3f45"
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: deck.r * 0.01
                text: key.modelData
                visible: deck.r >= 60
                color: "#80878e"
                font.pixelSize: Math.max(6, Math.round(deck.r * 0.085))
            }
        }
    }

    // Cue lever: tips forward while playing (arm down), back when paused.
    Item {
        x: deck.cx + deck.cue.x * deck.r
        y: deck.cy + deck.cue.y * deck.r

        Rectangle {
            anchors.centerIn: parent
            width: deck.r * 0.12
            height: width
            radius: width / 2
            color: "#1b1e22"
            border.width: Math.max(1, deck.r * 0.01)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            antialiasing: true
        }

        Rectangle {
            x: -width / 2
            y: -height + width / 2
            width: Math.max(2, deck.r * 0.045)
            height: deck.r * 0.20
            radius: width / 2
            antialiasing: true
            transformOrigin: Item.Bottom
            rotation: deck.playing ? 35 : -10
            Behavior on rotation {
                NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
            }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#5a6168" }
                GradientStop { position: 1.0; color: "#2c3035" }
            }
        }
    }
}
