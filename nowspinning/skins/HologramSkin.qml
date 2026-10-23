// Skin: the cover as a hologram, projected up from a small emitter.
//
// Cyan and see-through, with scanlines crawling up it, a brighter sweep
// running down it now and then, and a slow float. Every few seconds while
// playing the signal drops out for a moment: the picture jumps sideways in
// bands, splits into red and cyan, and settles.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the emitter projecting nothing.
//
// Options: holoColor (cyan, green, pink, amber, art for the cover's own
// colour, or any "#rrggbb"; anything else falls back to cyan), holoMotion (the float, the rings, the crawling lines) and
// holoGlitch (the dropouts), holoOpacity (how solid the projection is) and
// holoBase (the emitter and its beam; off, the picture fills the room).
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `accent`.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property bool blankLabel: false

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // Options, bound to config keys of the same name by the window.
    property string holoColor: "cyan"   // cyan | green | pink | amber | art | "#rrggbb"
    property bool holoMotion: true      // float, turning rings, crawling lines
    property bool holoGlitch: true      // the signal dropouts
    property real holoOpacity: 1        // how solid the projection is
    property bool holoBase: true        // the emitter and its beam; without
                                        // them the picture takes the room
    property color accent: "white"

    readonly property var palette: ({
        cyan: "#59f2ff", green: "#5dff9a", pink: "#ff6ad8", amber: "#ffbe4d"
    })
    readonly property bool hexColor: /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(holoColor)
    readonly property color beam: hexColor ? holoColor
        : holoColor === "art" && !Qt.colorEqual(accent, "white")
            ? Qt.hsla(accent.hslHue, Math.max(0.6, accent.hslSaturation), 0.65, 1)
            : (palette[holoColor] ?? palette.cyan)
    function glow(a) { return Qt.rgba(beam.r, beam.g, beam.b, a); }
    function haze(a) { return Qt.rgba(Qt.lighter(beam, 1.3).r, Qt.lighter(beam, 1.3).g, Qt.lighter(beam, 1.3).b, a); }

    readonly property bool moving: playing && holoMotion && !blankLabel

    implicitWidth: size
    implicitHeight: Math.round(size * (holoBase ? 1.16 : 1.0))

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false
    // Light doesn't cast one.
    readonly property bool ownShadow: true

    readonly property real pic: size * (holoBase ? 0.78 : 0.92)
    readonly property real picX: (size - pic) / 2
    readonly property real picY: size * 0.04
    readonly property real emitterY: size * 1.0

    // Slow float, only while playing.
    property real bob: 0
    SequentialAnimation on bob {
        running: skin.moving
        loops: Animation.Infinite
        NumberAnimation { to: -skin.size * 0.012; duration: 1800; easing.type: Easing.InOutSine }
        NumberAnimation { to: skin.size * 0.012; duration: 1800; easing.type: Easing.InOutSine }
    }

    // Light cone from the emitter's center up to the picture: a point at
    // the bottom, the picture's width at the top.
    Shape {
        anchors.fill: parent
        visible: skin.holoBase
        preferredRendererType: Shape.CurveRenderer
        opacity: skin.blankLabel ? 0.25 : 1
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: skin.emitterY; x2: 0; y2: skin.picY + skin.pic
                GradientStop { position: 0.0; color: skin.glow(0.40) }
                GradientStop { position: 1.0; color: skin.glow(0.03) }
            }
            startX: skin.size / 2; startY: skin.emitterY
            PathLine { x: skin.picX + skin.pic * 0.08; y: skin.picY + skin.pic }
            PathLine { x: skin.picX + skin.pic * 0.92; y: skin.picY + skin.pic }
            PathLine { x: skin.size / 2; y: skin.emitterY }
        }
    }

    // The emitter: a ring of dashes lying flat, seen at an angle, turning
    // while playing. Drawn as circles on
    // a square and squashed vertically, which is what puts them in
    // perspective.
    component SegmentRing: Item {
        id: ring
        property real radius: 10
        property int count: 12
        property real length: 4      // along the ring
        property real thickness: 2   // across it
        property real speed: 0       // degrees per second; negative turns back
        property real fade: 0        // how much every other segment dims
        property color color: skin.beam

        anchors.centerIn: parent
        width: radius * 2
        height: radius * 2

        NumberAnimation on rotation {
            running: skin.moving && ring.speed !== 0
            loops: Animation.Infinite
            from: ring.speed > 0 ? 0 : 360
            to: ring.speed > 0 ? 360 : 0
            duration: 360000 / Math.max(1, Math.abs(ring.speed))
        }

        Repeater {
            model: ring.count
            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 360 / ring.count
                Rectangle {
                    x: (ring.width - width) / 2
                    y: 0
                    width: ring.length
                    height: ring.thickness
                    radius: Math.min(width, height) * 0.3
                    color: ring.color
                    opacity: 1 - (index % 2) * ring.fade
                    antialiasing: true
                }
            }
        }
    }

    Item {
        id: emitter
        visible: skin.holoBase
        readonly property real d: skin.size * 0.92
        x: (skin.size - d) / 2
        y: skin.emitterY - d / 2
        width: d
        height: d
        opacity: skin.blankLabel ? 0.35 : (skin.playing ? 1 : 0.75)
        Behavior on opacity { NumberAnimation { duration: 400 } }
        transform: Scale { origin.x: emitter.d / 2; origin.y: emitter.d / 2; yScale: 0.30 }

        // Glow pooled on the floor.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: emitter.d / 2; centerY: emitter.d / 2
                    focalX: centerX; focalY: centerY
                    centerRadius: emitter.d / 2
                    focalRadius: 0
                    GradientStop { position: 0.0; color: skin.glow(0.22) }
                    GradientStop { position: 0.6; color: skin.glow(0.05) }
                    GradientStop { position: 1.0; color: skin.glow(0.0) }
                }
                startX: 0; startY: 0
                PathLine { x: emitter.d; y: 0 }
                PathLine { x: emitter.d; y: emitter.d }
                PathLine { x: 0; y: emitter.d }
                PathLine { x: 0; y: 0 }
            }
        }

        // Dashes.
        SegmentRing {
            radius: emitter.d * 0.27
            count: 16
            length: emitter.d * 0.06
            thickness: emitter.d * 0.035
            speed: 10
            fade: 0.5
            opacity: 0.8
        }

        // The lens, where the beam leaves.
        Rectangle {
            anchors.centerIn: parent
            width: emitter.d * 0.08
            height: width
            radius: width / 2
            color: Qt.lighter(skin.beam, 1.5)
            border.width: Math.max(1, emitter.d * 0.01)
            border.color: skin.beam
        }
    }

    // The projection.
    Item {
        id: projection
        x: skin.picX
        y: skin.picY + skin.bob
        width: skin.pic
        height: skin.pic
        visible: !skin.blankLabel
        opacity: skin.holoOpacity * (skin.playing ? 1 : 0.7)
        Behavior on opacity { NumberAnimation { duration: 400 } }

        property real jitter: 0
        property real split: 0

        Image {
            id: art
            anchors.fill: parent
            source: skin.blankLabel ? "" : skin.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize { width: 300; height: 300 }
            asynchronous: true
            visible: false
        }

        // Soft glow behind it.
        MultiEffect {
            anchors.fill: parent
            source: art
            colorization: 1
            colorizationColor: skin.beam
            blurEnabled: true
            blur: 1
            blurMax: 32
            brightness: 0.3
            opacity: 0.5
        }

        // Red and cyan copies, pulled apart during a dropout.
        MultiEffect {
            anchors.fill: parent
            anchors.leftMargin: -projection.split
            anchors.rightMargin: projection.split
            source: art
            colorization: 1
            colorizationColor: "#ff3a6a"
            opacity: projection.split !== 0 ? 0.45 : 0
        }

        MultiEffect {
            x: projection.jitter
            width: parent.width
            height: parent.height
            source: art
            colorization: 1
            colorizationColor: skin.beam
            brightness: 0.12
            contrast: 0.25
            opacity: 0.78
        }

        // Bands of the picture knocked sideways during a dropout.
        property var slices: []
        Repeater {
            model: projection.slices
            delegate: Item {
                required property var modelData
                y: modelData.y * projection.height
                width: projection.width
                height: modelData.h * projection.height
                clip: true
                MultiEffect {
                    x: modelData.dx * projection.width
                    y: -parent.y
                    width: projection.width
                    height: projection.height
                    source: art
                    colorization: 1
                    colorizationColor: "white"
                    opacity: 0.8
                }
            }
        }

        // Scanlines, crawling upward.
        Item {
            anchors.fill: parent
            clip: true
            Item {
                id: lines
                width: parent.width
                height: parent.height + 4
                NumberAnimation on y {
                    running: skin.moving
                    loops: Animation.Infinite
                    from: 0; to: -4
                    duration: 400
                }
                Repeater {
                    model: Math.ceil(lines.height / 4)
                    Rectangle {
                        required property int index
                        y: index * 4
                        width: lines.width
                        height: 2
                        color: Qt.rgba(0, 0.05, 0.08, 0.45)
                    }
                }
            }

            // A brighter band sweeping down every few seconds.
            Rectangle {
                id: sweep
                width: parent.width
                height: parent.height * 0.12
                y: -height
                gradient: Gradient {
                    GradientStop { position: 0.0; color: skin.haze(0) }
                    GradientStop { position: 0.5; color: skin.haze(0.22) }
                    GradientStop { position: 1.0; color: skin.haze(0) }
                }
                SequentialAnimation on y {
                    running: skin.moving
                    loops: Animation.Infinite
                    NumberAnimation { from: -sweep.height; to: projection.height; duration: 1400; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 2200 }
                }
            }
        }

        // Thin frame, like the edge of the projected plane.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: skin.haze(0.35)
        }
    }

    // A dropout: a few frames of displaced bands and a colour split.
    Timer {
        id: dropout
        property int ticks: 0
        interval: 55
        repeat: true
        onTriggered: {
            if (++ticks > 7) {
                stop();
                projection.slices = [];
                projection.jitter = 0;
                projection.split = 0;
                return;
            }
            const next = [];
            for (let i = 0; i < 3; i++)
                next.push({ y: Math.random() * 0.9, h: 0.04 + Math.random() * 0.12, dx: (Math.random() - 0.5) * 0.3 });
            projection.slices = next;
            projection.jitter = (Math.random() - 0.5) * skin.size * 0.03;
            projection.split = skin.size * (0.01 + Math.random() * 0.03);
        }
    }

    function glitchNow() {
        dropout.ticks = 0;
        dropout.restart();
    }
    onArtUrlChanged: if (!blankLabel && holoGlitch) glitchNow()

    Timer {
        running: skin.playing && skin.holoGlitch && !skin.blankLabel
        interval: 2500 + Math.random() * 4000
        repeat: true
        onTriggered: {
            skin.glitchNow();
            interval = 2500 + Math.random() * 4000;
        }
    }
}
