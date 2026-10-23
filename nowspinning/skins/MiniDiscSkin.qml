// Skin: a MiniDisc, with the cover art as its label.
//
// The disc lives sealed inside the cartridge: what shows it spinning is a
// window in the lower half, behind a metal shutter. The shutter slides open
// while playing and closes on pause, the way it does when a real one goes
// into a player and comes back out.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// Flips like the vinyl skin to show the track info: the back is blank.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `accent`.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false

    // Tints the plastic, faintly. White means no tint.
    property color accent: "white"

    // Same 3600 rpm-ish feel as the CD, scaled down the same way.
    property real spinDegreesPerSecond: 30

    // Back side: no label printed, dark enough for the track info's text.
    property bool blankLabel: false

    property bool lightMotion: true  // swaying on its own
    property bool lightTilt: true    // turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // 68 x 72 mm, the real cartridge's proportions.
    readonly property real w: size
    readonly property real h: Math.round(size * 72 / 68)

    readonly property real boxFactor: 1.06
    readonly property rect faceRect: Qt.rect(0, 0, w, h)
    readonly property bool faceIsCircle: false

    implicitWidth: w
    implicitHeight: h

    readonly property bool tinted: !Qt.colorEqual(accent, "white")
    readonly property color plastic: tinted
        ? Qt.tint("#2b3038", Qt.rgba(accent.r, accent.g, accent.b, 0.30))
        : "#2b3038"

    // The window onto the disc, in the lower half.
    readonly property rect hole: Qt.rect(w * 0.20, h * 0.58, w * 0.60, h * 0.34)

    // The disc sits low in the cartridge, so its hub shows through the
    // window; on a real one it's centered, but then the label would have
    // to shrink to nothing.
    readonly property real discSize: w * 0.92
    readonly property point discCenter: Qt.point(w / 2, h * 0.76)

    // 0 = shut, 1 = open.
    property real open: playing ? 1 : 0
    Behavior on open {
        NumberAnimation { duration: 520; easing.type: Easing.InOutCubic }
    }

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: skin.lightMotion
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // Turns toward the light, as much as the foil card.
    transform: [
        Tilt { target: skin; amount: light.lightX; degrees: 9 },
        Tilt { target: skin; amount: light.lightY; degrees: 9; vertical: true }
    ]

    SpinDriver {
        id: spin
        playing: skin.playing
        degreesPerSecond: skin.spinDegreesPerSecond
    }

    // Cartridge body, with the one chamfered corner every MiniDisc has.
    Shape {
        id: body
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        readonly property real r: skin.w * 0.04
        readonly property real c: skin.w * 0.09

        ShapePath {
            strokeWidth: Math.max(1, skin.w * 0.006)
            strokeColor: Qt.rgba(1, 1, 1, 0.06)
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: skin.h
                GradientStop { position: 0.0; color: Qt.lighter(skin.plastic, 1.25) }
                GradientStop { position: 1.0; color: Qt.darker(skin.plastic, 1.25) }
            }

            startX: body.r; startY: 0
            PathLine { x: skin.w - body.c; y: 0 }
            PathLine { x: skin.w; y: body.c }
            PathLine { x: skin.w; y: skin.h - body.r }
            PathArc { x: skin.w - body.r; y: skin.h; radiusX: body.r; radiusY: body.r }
            PathLine { x: body.r; y: skin.h }
            PathArc { x: 0; y: skin.h - body.r; radiusX: body.r; radiusY: body.r }
            PathLine { x: 0; y: body.r }
            PathArc { x: body.r; y: 0; radiusX: body.r; radiusY: body.r }
        }
    }

    // Label, upper half.
    Item {
        id: labelArea
        x: skin.w * 0.08
        y: skin.h * 0.06
        width: skin.w * 0.84
        height: skin.h * 0.46

        Rectangle {
            id: labelShape
            anchors.fill: parent
            radius: skin.w * 0.025
            // Dark, not paper white: it shows as a fringe around the art's
            // rounded, antialiased edge.
            color: "#15181d"
            antialiasing: true
        }

        // Drawn 4% past the label on every side and cut back by the mask:
        // plenty of covers carry a thin white border of their own (scans,
        // Spotify's art among them), and on a rectangular label it lands
        // exactly on the edge as a pale frame.
        readonly property real bleed: width * 0.04

        CrossfadeImage {
            id: art
            x: -labelArea.bleed
            y: -labelArea.bleed
            width: labelArea.width + 2 * labelArea.bleed
            height: labelArea.height + 2 * labelArea.bleed
            source: skin.blankLabel ? "" : skin.artUrl
            visible: false
            layer.enabled: true
        }

        // Same geometry as `art`, with the label's shape inset by the bleed.
        Item {
            id: labelMask
            anchors.fill: art
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: labelArea.bleed
                radius: labelShape.radius
                color: "black"
                antialiasing: true
            }
        }

        MultiEffect {
            anchors.fill: art
            source: art
            maskEnabled: true
            maskSource: labelMask
            // Without these the mask's antialiased edge leaves a pale halo
            // around the art.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            visible: art.ready && !skin.blankLabel
        }

        // Insertion arrow, pressed into the plastic above the label.
        Shape {
            x: parent.width / 2 - width / 2
            y: -skin.h * 0.045
            width: skin.w * 0.06
            height: skin.h * 0.03
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.rgba(1, 1, 1, 0.22)
                startX: 0; startY: 0
                PathLine { x: skin.w * 0.06; y: 0 }
                PathLine { x: skin.w * 0.03; y: skin.h * 0.03 }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // Window recess: dark, so the disc behind it reads as being inside.
    Rectangle {
        x: skin.hole.x - 1
        y: skin.hole.y - 1
        width: skin.hole.width + 2
        height: skin.hole.height + 2
        radius: skin.w * 0.02
        color: "#0c0e11"
        antialiasing: true
    }

    // The disc, seen only through the window.
    Item {
        x: skin.hole.x
        y: skin.hole.y
        width: skin.hole.width
        height: skin.hole.height
        clip: true

        Item {
            x: skin.discCenter.x - skin.hole.x - width / 2
            y: skin.discCenter.y - skin.hole.y - height / 2
            width: skin.discSize
            height: skin.discSize

            DiscFace {
                anchors.centerIn: parent
                size: skin.discSize
                rotation: spin.angle
                artUrl: ""
                labelSize: 0
                holeRadius: 0

                bodyColor: "#a9b0bb"
                rimColor: "#d5dae2"
                rimWidth: 3
                grooveInner: 150
                grooveOuter: 486
                grooveStep: 7
                grooveLight: Qt.rgba(1, 1, 1, 0.14)
                grooveAccent: Qt.rgba(1, 1, 1, 0.26)
                grooveAccentEvery: 9
                grooveDark: Qt.rgba(0, 0, 0, 0.10)
                bandRadii: []
            }

            // Metal hub. Its three holes are what show it turning: a plain
            // disc of rings looks the same at every angle.
            Item {
                anchors.centerIn: parent
                width: skin.discSize * 0.26
                height: width
                rotation: spin.angle

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#e4e8ee" }
                        GradientStop { position: 1.0; color: "#7d848e" }
                    }
                    border.width: Math.max(1, skin.w * 0.006)
                    border.color: "#5c636c"
                }

                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property real a: index * Math.PI * 2 / 3
                        width: skin.discSize * 0.035
                        height: width
                        radius: width / 2
                        color: "#2a2e34"
                        antialiasing: true
                        x: parent.width / 2 + parent.width * 0.3 * Math.cos(a) - width / 2
                        y: parent.height / 2 + parent.width * 0.3 * Math.sin(a) - height / 2
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.22
                    height: width
                    radius: width / 2
                    color: "#3a3f46"
                    antialiasing: true
                }
            }

            // Light across the disc stays put while it turns.
            Sheen {
                anchors.fill: parent
                startAngle: 200
                following: light.following
                heading: light.headingFrom(skin.discCenter.x, skin.discCenter.y)
                holeRadius: 0
            }
        }
    }

    // Shutter: brushed metal over the window, slid aside while playing.
    // Clipped to the body so it can't stick out past the cartridge.
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: shutter
            x: skin.hole.x - skin.w * 0.06 + skin.open * (skin.hole.width + skin.w * 0.06)
            y: skin.hole.y - skin.h * 0.03
            width: skin.hole.width + skin.w * 0.12
            height: skin.hole.height + skin.h * 0.06
            radius: skin.w * 0.012
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "#8e959e" }
                GradientStop { position: 0.30; color: "#d3d8de" }
                GradientStop { position: 0.55; color: "#a8afb7" }
                GradientStop { position: 1.00; color: "#7b828b" }
            }
            border.width: Math.max(1, skin.w * 0.005)
            border.color: Qt.rgba(0, 0, 0, 0.35)

            // Pressed-in grip lines at the leading edge.
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: shutter.width * 0.08 + index * skin.w * 0.022
                    y: shutter.height * 0.22
                    width: Math.max(1, skin.w * 0.007)
                    height: shutter.height * 0.56
                    color: Qt.rgba(0, 0, 0, 0.22)
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: shutter.width * 0.08
                text: "MD"
                color: Qt.rgba(0, 0, 0, 0.30)
                font.pixelSize: Math.max(7, Math.round(skin.w * 0.075))
                font.weight: Font.Black
                font.italic: true
            }
        }
    }

    // Write-protect tab, bottom left.
    Rectangle {
        x: skin.w * 0.05
        y: skin.h * 0.90
        width: skin.w * 0.07
        height: skin.h * 0.05
        radius: skin.w * 0.01
        color: Qt.darker(skin.plastic, 1.6)
        antialiasing: true
    }

    // A glint across the cartridge, as on the foil card. Clipped to its
    // box; the chamfered corner doesn't show it at this strength.
    Glint {
        lightX: light.lightX
        strength: skin.blankLabel ? 0.08 : 0.22
    }
}
