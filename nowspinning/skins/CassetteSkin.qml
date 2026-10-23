// Skin: a compact cassette, with the cover art as its label.
//
// The one skin where the object itself shows how far into the track you
// are: tape winds off the left reel onto the right one as it plays. Vinyl
// and CD only get that from the ring drawn around them.
//
// Both reels keep the tape moving at one constant speed, the way a capstan
// does, so the reel with less tape on it has to turn faster. That falls out
// of the arithmetic below rather than being faked, and it's what makes the
// two hubs visibly drift out of step over the length of a song.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// Flips like the vinyl skin to show the track info: the back is side B.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `progress` and `accent`.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false

    // 0..1 of the track: how the tape is split between the two reels.
    property real progress: 0

    // Tints the plastic, faintly. White means no tint.
    property color accent: "white"

    // Degrees per second of a reel holding half the tape. The fuller reel
    // turns slower than this and the emptier one faster.
    property real spinDegreesPerSecond: 40

    // How solid the plastic is. 1 is an ordinary shell. Lower is a clear one:
    // the desktop shows through it, and so does what's inside, the full tape
    // packs, the guide rollers, and the tape running between them. The label
    // stays solid either way; `discOpacity` is the one that fades everything.
    property real shellOpacity: 1

    // Back side: side B, blank, dark enough for the track info's white text.
    property bool blankLabel: false

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // A real cassette is 100.4 x 63.8 mm.
    readonly property real bodyH: Math.round(size * 0.90)
    readonly property real bodyW: Math.round(bodyH * 1.574)

    readonly property real boxFactor: bodyW / size
    readonly property rect faceRect: Qt.rect((width - bodyW) / 2,
                                             (height - bodyH) / 2, bodyW, bodyH)
    readonly property bool faceIsCircle: false

    implicitWidth: bodyW
    implicitHeight: bodyH

    // ---------------------------------------------------------------
    // Reels
    // ---------------------------------------------------------------
    // Everything in units of the body's height.
    readonly property real hubRadius: bodyH * 0.085
    readonly property real packEmpty: bodyH * 0.10    // bare hub, no tape
    readonly property real packFull: bodyH * 0.30     // all the tape

    // Tape is a strip wound into a disc, so what gets split between the reels
    // is area, not radius: halfway through, each reel holds half the tape's
    // area, which puts both at about 0.75 of the full radius, not half.
    function packRadius(share) {
        const e2 = packEmpty * packEmpty;
        return Math.sqrt(e2 + Math.max(0, Math.min(1, share)) * (packFull * packFull - e2));
    }

    readonly property real leftPack: packRadius(1 - progress)
    readonly property real rightPack: packRadius(progress)

    // Constant tape speed means angular speed goes as 1 / radius. Scaled so
    // a reel holding half the tape turns at exactly `spinDegreesPerSecond`.
    readonly property real halfPack: packRadius(0.5)

    readonly property real hubY: bodyH * 0.44
    readonly property real leftHubX: bodyW * 0.29
    readonly property real rightHubX: bodyW * 0.71

    SpinDriver {
        id: leftSpin
        playing: skin.playing
        degreesPerSecond: skin.spinDegreesPerSecond * skin.halfPack / skin.leftPack
    }

    SpinDriver {
        id: rightSpin
        playing: skin.playing
        degreesPerSecond: skin.spinDegreesPerSecond * skin.halfPack / skin.rightPack
    }

    readonly property bool accentIsColor: accent.hslSaturation > 0.05

    // Below about 0.15 the shell stops reading as an object at all.
    readonly property real shell: Math.max(0.15, Math.min(1, shellOpacity))

    // One reel: the wound tape, and the hub it's wound on. Everything comes
    // in through properties, since an inline component can't see this
    // file's ids.
    component Reel: Item {
        id: reel

        property real pack       // radius of the wound tape
        property real hubRadius
        property real angle
        property real edge       // outline width

        width: 0
        height: 0

        Rectangle {
            anchors.centerIn: parent
            width: reel.pack * 2
            height: width
            radius: width / 2
            color: "#3d2b21"
            border.width: reel.edge
            border.color: "#5a4234"
            antialiasing: true
        }

        // A ring with teeth pointing into its hole, the ones that grip the
        // spindle. The teeth are the only part where turning shows. Both
        // reels turn counterclockwise with the tape running along the
        // bottom, left to right.
        Item {
            anchors.centerIn: parent
            width: reel.hubRadius * 2
            height: width
            rotation: -reel.angle

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#d9dade"
                antialiasing: true
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.62
                height: width
                radius: width / 2
                color: "#0b0c0f"
                antialiasing: true
            }

            Repeater {
                model: 6

                Rectangle {
                    x: parent.width / 2 - width / 2
                    y: parent.height / 2 - height / 2
                    width: parent.width * 0.16
                    height: parent.height * 0.70
                    color: "#d9dade"
                    antialiasing: true
                    transform: Rotation {
                        origin.x: width / 2
                        origin.y: height / 2
                        angle: index * 60
                    }

                    // Only the ends poke into the hole: a spoke through the
                    // middle would read as a cross.
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 2
                        height: parent.height * 0.62
                        color: "#0b0c0f"
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------
    // Shell
    // ---------------------------------------------------------------
    Rectangle {
        id: body
        x: skin.faceRect.x
        y: skin.faceRect.y
        width: skin.bodyW
        height: skin.bodyH
        radius: skin.bodyH * 0.05
        antialiasing: true

        readonly property color plastic: skin.accentIsColor
            ? Qt.tint("#1b1d22", Qt.rgba(skin.accent.r, skin.accent.g, skin.accent.b, 0.16))
            : "#1b1d22"
        color: Qt.rgba(plastic.r, plastic.g, plastic.b, skin.shell)
        Behavior on color { ColorAnimation { duration: 600 } }

        border.width: Math.max(1, skin.bodyH * 0.012)
        border.color: Qt.rgba(1, 1, 1, 0.10)

        // Molded plastic catches light along the top and falls off below.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.09) }
                GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.30 * skin.shell) }
            }
        }

        // What a clear shell lets you see: the whole of both tape packs, not
        // just the slice through the window, the two guide rollers in the
        // bottom corners, and the tape running from one pack, around the
        // rollers and along the bottom, up into the other. Fades in as the
        // plastic fades out; with an opaque shell it isn't drawn at all.
        Item {
            id: internals
            anchors.fill: parent
            opacity: 1 - skin.shell
            visible: opacity > 0.01

            readonly property real rollerR: skin.bodyH * 0.045
            readonly property point leftRoller: Qt.point(skin.bodyW * 0.13, skin.bodyH * 0.905)
            readonly property point rightRoller: Qt.point(skin.bodyW * 0.87, skin.bodyH * 0.905)
            // Level with the strip of tape drawn along the head opening.
            readonly property real tapeY: skin.bodyH * 0.954

            // Where the tape leaves a pack for its roller: the point on the
            // pack facing the roller. Not the true tangent, but at this size
            // the difference is under a pixel.
            function leave(cx, pack, roller) {
                const dx = roller.x - cx;
                const dy = roller.y - skin.hubY;
                const d = Math.max(1, Math.sqrt(dx * dx + dy * dy));
                return Qt.point(cx + pack * dx / d, skin.hubY + pack * dy / d);
            }

            Repeater {
                model: 2

                Rectangle {
                    readonly property real pack: index === 0 ? skin.leftPack : skin.rightPack
                    x: (index === 0 ? skin.leftHubX : skin.rightHubX) - pack
                    y: skin.hubY - pack
                    width: pack * 2
                    height: width
                    radius: width / 2
                    color: "#3d2b21"
                    border.width: Math.max(1, skin.bodyH * 0.006)
                    border.color: "#5a4234"
                    antialiasing: true
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: tapePath
                    readonly property point from: internals.leave(skin.leftHubX, skin.leftPack, internals.leftRoller)
                    readonly property point to: internals.leave(skin.rightHubX, skin.rightPack, internals.rightRoller)

                    strokeColor: "#4a3528"
                    strokeWidth: Math.max(1, skin.bodyH * 0.014)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: from.x; startY: from.y
                    PathLine { x: internals.leftRoller.x - internals.rollerR; y: internals.leftRoller.y }
                    PathLine { x: internals.leftRoller.x; y: internals.tapeY }
                    PathLine { x: internals.rightRoller.x; y: internals.tapeY }
                    PathLine { x: internals.rightRoller.x + internals.rollerR; y: internals.rightRoller.y }
                    PathLine { x: tapePath.to.x; y: tapePath.to.y }
                }
            }

            Repeater {
                model: [internals.leftRoller, internals.rightRoller]

                Rectangle {
                    x: modelData.x - internals.rollerR
                    y: modelData.y - internals.rollerR
                    width: internals.rollerR * 2
                    height: width
                    radius: width / 2
                    color: "#c9cbd1"
                    border.width: Math.max(1, internals.rollerR * 0.35)
                    border.color: "#7d818a"
                    antialiasing: true
                }
            }
        }

        // Screws, one per corner. Real shells often have a fifth in the
        // middle of the bottom edge, but here it lands on the head opening.
        Repeater {
            model: [[0.045, 0.075], [0.955, 0.075], [0.045, 0.925], [0.955, 0.925]]

            Rectangle {
                readonly property real r: Math.max(1.5, skin.bodyH * 0.026)
                x: modelData[0] * skin.bodyW - r
                y: modelData[1] * skin.bodyH - r
                width: r * 2
                height: r * 2
                radius: r
                color: "#4a4e57"
                border.width: Math.max(1, r * 0.35)
                border.color: "#2a2c31"
                antialiasing: true

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.6
                    height: Math.max(1, parent.height * 0.14)
                    rotation: 35
                    color: "#23252a"
                    antialiasing: true
                }
            }
        }

        // ---------------------------------------------------------------
        // Label
        // ---------------------------------------------------------------
        // A real label is die-cut around the window. It matters once the shell
        // is clear: without the hole, the cover art would show through the
        // window from behind, where only the inside of the cassette should be.
        Item {
            id: label
            x: skin.bodyW * 0.065
            y: skin.bodyH * 0.075
            width: skin.bodyW * 0.87
            height: skin.bodyH * 0.62

            readonly property real radius: skin.bodyH * 0.025

            Item {
                id: labelFace
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    color: skin.blankLabel ? "#26282e" : "#3a3c42"
                }

                CrossfadeImage {
                    anchors.fill: parent
                    source: skin.blankLabel ? "" : skin.artUrl
                }

                // Knocks the cover back so the window and the strip read over it.
                Rectangle {
                    anchors.fill: parent
                    visible: !skin.blankLabel
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.10) }
                        GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.45) }
                    }
                }

                // The strip across the top where a side letter and a title go.
                Rectangle {
                    id: strip
                    width: parent.width
                    height: skin.bodyH * 0.135
                    color: Qt.rgba(0, 0, 0, 0.55)

                    Text {
                        id: side
                        anchors.left: parent.left
                        anchors.leftMargin: skin.bodyW * 0.022
                        anchors.verticalCenter: parent.verticalCenter
                        text: skin.blankLabel ? "B" : "A"
                        color: "white"
                        font.pixelSize: Math.max(7, Math.round(skin.bodyH * 0.095))
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        anchors.left: side.right
                        anchors.leftMargin: skin.bodyW * 0.018
                        anchors.right: parent.right
                        anchors.rightMargin: skin.bodyW * 0.022
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: parent.height * 0.24
                        height: Math.max(1, skin.bodyH * 0.006)
                        color: skin.accentIsColor
                            ? Qt.rgba(skin.accent.r, skin.accent.g, skin.accent.b, 0.7)
                            : Qt.rgba(1, 1, 1, 0.28)
                    }
                }
            }

            // The label's outline with the window's outline cut out of it.
            Shape {
                id: labelMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "black"
                    fillRule: ShapePath.OddEvenFill
                    strokeWidth: -1

                    PathRectangle {
                        width: label.width
                        height: label.height
                        radius: label.radius
                    }

                    PathRectangle {
                        x: tapeWindow.x - label.x
                        y: tapeWindow.y - label.y
                        width: tapeWindow.width
                        height: tapeWindow.height
                        radius: tapeWindow.radius
                    }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: labelFace
                maskEnabled: true
                maskSource: labelMask
            }
        }

        // ---------------------------------------------------------------
        // Window, with the reels behind it
        // ---------------------------------------------------------------
        Rectangle {
            id: tapeWindow
            x: skin.bodyW * 0.17
            y: skin.bodyH * 0.285
            width: skin.bodyW * 0.66
            height: skin.bodyH * 0.31
            radius: skin.bodyH * 0.04
            // The inside of the shell: dark when it's solid, and just as see-
            // through as the rest of the plastic when it isn't.
            color: Qt.rgba(0.04, 0.05, 0.06, Math.max(0.25, skin.shell))
            antialiasing: true
            clip: true

            // On the blank side the info card's text sits right over this,
            // so the reels step back.
            opacity: skin.blankLabel ? 0.35 : 1

            // Two instances rather than a Repeater over a model: a model
            // built from the spin angles would be rebuilt, delegates and
            // all, on every tick of the spin.
            // Positions are in body coordinates, shifted into the window's.
            Reel {
                x: skin.leftHubX - tapeWindow.x
                y: skin.hubY - tapeWindow.y
                pack: skin.leftPack
                hubRadius: skin.hubRadius
                angle: leftSpin.angle
                edge: Math.max(1, skin.bodyH * 0.006)
            }

            Reel {
                x: skin.rightHubX - tapeWindow.x
                y: skin.hubY - tapeWindow.y
                pack: skin.rightPack
                hubRadius: skin.hubRadius
                angle: rightSpin.angle
                edge: Math.max(1, skin.bodyH * 0.006)
            }

            // Smoked plastic over it all.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.00) }
                    GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.06) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.00) }
                    GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.03) }
                }
            }
        }

        Rectangle {
            x: tapeWindow.x
            y: tapeWindow.y
            width: tapeWindow.width
            height: tapeWindow.height
            radius: tapeWindow.radius
            color: "transparent"
            border.width: Math.max(1, skin.bodyH * 0.01)
            border.color: Qt.rgba(1, 1, 1, 0.16)
            antialiasing: true
        }

        // ---------------------------------------------------------------
        // Head opening along the bottom, with the tape running across it
        // ---------------------------------------------------------------
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillColor: Qt.rgba(0, 0, 0, 0.32 * skin.shell)
                startX: skin.bodyW * 0.21; startY: skin.bodyH * 0.76
                PathLine { x: skin.bodyW * 0.79; y: skin.bodyH * 0.76 }
                PathLine { x: skin.bodyW * 0.74; y: skin.bodyH }
                PathLine { x: skin.bodyW * 0.26; y: skin.bodyH }
                PathLine { x: skin.bodyW * 0.21; y: skin.bodyH * 0.76 }
            }
        }

        Rectangle {
            x: skin.bodyW * 0.25
            y: skin.bodyH * 0.945
            width: skin.bodyW * 0.50
            height: Math.max(1, skin.bodyH * 0.018)
            color: "#3d2b21"
        }

        Repeater {
            model: [0.36, 0.5, 0.64]

            Rectangle {
                readonly property real r: skin.bodyH * 0.04
                x: modelData * skin.bodyW - r
                y: skin.bodyH * 0.855 - r
                width: r * 2
                height: r * 2
                radius: r * 0.3
                color: "#08090b"
                antialiasing: true
            }
        }
    }
}
