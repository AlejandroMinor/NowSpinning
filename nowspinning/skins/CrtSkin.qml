// Skin: the cover on an old CRT: scanlines, colour fringes, dark corners, a
// faint flicker and a glitch every few seconds while playing, and one on
// every new track. The glitch is one of EFFECTS, or a random one each time.
//
// Ported from HyprFlow's media panel skins. The back, for the track info,
// is the set switched off: black glass, glare, no picture.
//
// See VinylSkin.qml for the skin contract.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property bool blankLabel: false
    property bool showBezel: true
    property string effect: "random"  // or one of effects
    readonly property var effects: ["slices", "roll", "static", "split", "channel"]

    implicitWidth: size
    implicitHeight: Math.round(size * 0.84)

    readonly property bool supportsFullArt: false
    property bool artFull: false
    readonly property real boxFactor: 1
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Switched off on the back: no picture, so nothing to glitch either.
    readonly property string picture: blankLabel ? "" : artUrl

    readonly property real inset: showBezel ? size * 0.07 : 0
    property real splitBoost: 0  // the split glitch pulls the fringes apart
    readonly property real shift: size * 0.012 + splitBoost  // colour fringe offset

    // The bezel: a dark plastic frame around the glass.
    Rectangle {
        anchors.fill: parent
        visible: skin.showBezel
        radius: skin.size * 0.09
        color: "#1c1c1c"
        border { width: 1; color: "#333333" }
    }

    ClippingRectangle {
        id: screen
        anchors { fill: parent; margins: skin.inset }
        radius: skin.size * 0.06
        color: "black"

        Item {
            id: picture
            anchors.fill: parent
            transform: [
                Translate { id: roll; y: 0 },
                Scale { id: squash; origin.y: screen.height / 2; yScale: 1 }
            ]

            // Red and blue copies a little apart: the fringes of a CRT.
            Image {
                id: art
                anchors.fill: parent
                source: skin.picture
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 300; height: 300 }
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                anchors.leftMargin: -skin.shift
                anchors.rightMargin: skin.shift
                source: art
                colorization: 1
                colorizationColor: "#ff2030"
                opacity: 0.55
            }
            MultiEffect {
                anchors.fill: parent
                anchors.leftMargin: skin.shift
                anchors.rightMargin: -skin.shift
                source: art
                colorization: 1
                colorizationColor: "#2060ff"
                opacity: 0.55
            }
            MultiEffect {
                anchors.fill: parent
                source: art
                opacity: 0.8
                saturation: 0.15
            }

            // A faint flicker while playing.
            SequentialAnimation on opacity {
                running: skin.playing && !skin.blankLabel
                loops: Animation.Infinite
                PauseAnimation { duration: 1700 }
                NumberAnimation { to: 0.9; duration: 60 }
                NumberAnimation { to: 1; duration: 90 }
                PauseAnimation { duration: 900 }
                NumberAnimation { to: 0.95; duration: 40 }
                NumberAnimation { to: 1; duration: 60 }
            }
        }

        // roll: the picture slides down, its copy following above it past a
        // black band, as when the vertical hold slips.
        ShaderEffectSource {
            anchors.fill: parent
            visible: roll.y !== 0
            sourceItem: picture
            transform: Translate { y: roll.y - screen.height }
        }
        Rectangle {
            visible: roll.y !== 0
            y: roll.y - height
            width: screen.width
            height: screen.height * 0.07
            color: "black"
        }
        NumberAnimation {
            id: rollAnim
            target: roll; property: "y"
            from: 0; to: screen.height
            duration: 520
            easing.type: Easing.InOutQuad
            onFinished: roll.y = 0
        }

        // static: snow for a moment.
        Canvas {
            id: snow
            width: 64
            height: 48
            transform: Scale { xScale: screen.width / 64; yScale: screen.height / 48 }
            property bool on: false
            smooth: false
            opacity: on ? 0.75 : 0
            onPaint: {
                const ctx = getContext("2d");
                // fillRect, not putImageData: written pixel by pixel, the
                // image data never showed.
                for (let y = 0; y < 48; y++) {
                    for (let x = 0; x < 64; x++) {
                        const v = Math.random();
                        ctx.fillStyle = Qt.rgba(v, v, v, 1);
                        ctx.fillRect(x, y, 1, 1);
                    }
                }
            }
        }
        Timer {
            id: snowTimer
            property int ticks: 0
            interval: 50
            repeat: true
            onTriggered: {
                if (++ticks > 9) {
                    stop();
                    snow.on = false;
                    return;
                }
                snow.on = true;
                snow.requestPaint();
            }
        }

        // split: the colour fringes yank apart and come back.
        SequentialAnimation {
            id: splitAnim
            NumberAnimation { target: skin; property: "splitBoost"; to: skin.size * 0.05; duration: 70 }
            NumberAnimation { target: skin; property: "splitBoost"; to: -skin.size * 0.03; duration: 90 }
            NumberAnimation { target: skin; property: "splitBoost"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }

        // channel: squashed to a bright line and back, like changing channel.
        Rectangle {
            anchors.centerIn: parent
            width: screen.width
            height: 2
            color: "white"
            visible: squash.yScale < 0.08
        }
        SequentialAnimation {
            id: channelAnim
            NumberAnimation { target: squash; property: "yScale"; to: 0.02; duration: 120; easing.type: Easing.InQuad }
            PauseAnimation { duration: 90 }
            NumberAnimation { target: squash; property: "yScale"; to: 1; duration: 200; easing.type: Easing.OutBack }
        }

        // slices: bands of the picture shoved sideways for a moment.
        property var slices: []
        Repeater {
            model: screen.slices
            delegate: Item {
                required property var modelData
                y: modelData.y * screen.height
                width: screen.width
                height: modelData.h * screen.height
                clip: true
                Image {
                    x: modelData.dx * screen.width
                    y: -parent.y
                    width: screen.width
                    height: screen.height
                    source: skin.picture
                    fillMode: Image.PreserveAspectCrop
                    sourceSize { width: 300; height: 300 }
                }
            }
        }
        Timer {
            id: glitch
            property int ticks: 0
            interval: 60
            repeat: true
            onTriggered: {
                if (++ticks > 8) {
                    stop();
                    screen.slices = [];
                    return;
                }
                const next = [];
                for (let i = 0; i < 4; i++)
                    next.push({ y: Math.random() * 0.9, h: 0.03 + Math.random() * 0.1, dx: (Math.random() - 0.5) * 0.25 });
                screen.slices = next;
            }
        }

        // Scanlines.
        Repeater {
            model: Math.floor(screen.height / 3)
            delegate: Rectangle {
                required property int index
                y: index * 3
                width: screen.width
                height: 1
                color: "black"
                opacity: 0.3
            }
        }

        // Dark corners and a glare on the glass.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: screen.width / 2; centerY: screen.height / 2
                    focalX: centerX; focalY: centerY
                    centerRadius: Math.max(screen.width, screen.height) * 0.72
                    focalRadius: 0
                    GradientStop { position: 0.6; color: "transparent" }
                    GradientStop { position: 1; color: "#b0000000" }
                }
                startX: 0; startY: 0
                PathLine { x: screen.width; y: 0 }
                PathLine { x: screen.width; y: screen.height }
                PathLine { x: 0; y: screen.height }
                PathLine { x: 0; y: 0 }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.1) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }
    }

    function glitchNow() {
        const kind = effect === "random" ? effects[Math.floor(Math.random() * effects.length)] : effect;
        switch (kind) {
        case "roll": rollAnim.restart(); break;
        case "static": snowTimer.ticks = 0; snowTimer.restart(); break;
        case "split": splitAnim.restart(); break;
        case "channel": channelAnim.restart(); break;
        default: glitch.ticks = 0; glitch.restart();
        }
    }
    onArtUrlChanged: if (!blankLabel) glitchNow()
    // While playing, a glitch every 3 to 7 seconds.
    Timer {
        running: skin.playing && !skin.blankLabel
        interval: 3000 + Math.random() * 4000
        repeat: true
        onTriggered: {
            skin.glitchNow();
            interval = 3000 + Math.random() * 4000;
        }
    }
}
