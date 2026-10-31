// Skin: the cover inside a cyberpunk HUD panel.
//
// A yellow frame with two corners cut, the cover behind scanlines with a
// cyan scan bar running down it, the title and artist in monospace and the
// progress as a row of segments. Every few seconds while playing, on each
// new track and when the pointer comes in, the picture glitches: it jumps
// sideways in bands and settles.
//
// Under the pointer the panel turns toward it and its glow comes up.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the empty panel.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist`, `progress` and `trackChangeToken`.
import QtQuick
import QtQuick.Effects
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property string artist: ""
    property real progress: 0
    property int trackChangeToken: 0
    property bool blankLabel: false
    property bool lightMotion: true   // the scan bar and the glitches on their own
    property bool lightTilt: true     // the panel turning toward the pointer
    // How loud the low end is right now, 0..1, while `audioReact` is on
    // (AudioLevels.qml); 0 otherwise, and the skin keeps its own pulse.
    property real audioLevel: 0
    // A hard hit glitches it too.
    onAudioLevelChanged: if (audioLevel > 0.9) glitch()

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color yellow: "#fcee0a"
    readonly property color cyan: "#00f0ff"
    readonly property color pink: "#ff2a6d"
    readonly property color panel: "#0d0f14"

    // The panel, and room around it for its glow.
    readonly property real u: size * 0.88
    readonly property real margin: (size - u) / 2
    readonly property real panelH: Math.round(u * 1.27)

    implicitWidth: size
    implicitHeight: Math.round(panelH + 2 * margin)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(margin, margin, u, panelH)
    readonly property bool faceIsCircle: false
    // It glows instead.
    readonly property bool ownShadow: true

    readonly property real pad: u * 0.07
    readonly property real cut: u * 0.09
    readonly property real line: Math.max(2, u * 0.012)

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
        onFollowingChanged: if (following) skin.glitch()
    }

    // How far the picture's bands are thrown sideways, -1..1.
    property real jolt: 0
    function glitch() {
        if (!blankLabel && !joltAnim.running)
            joltAnim.start();
    }
    onTrackChangeTokenChanged: glitch()
    SequentialAnimation {
        id: joltAnim
        NumberAnimation { target: skin; property: "jolt"; to: -1; duration: 0 }
        PauseAnimation { duration: 60 }
        NumberAnimation { target: skin; property: "jolt"; to: 0.7; duration: 0 }
        PauseAnimation { duration: 50 }
        NumberAnimation { target: skin; property: "jolt"; to: -0.4; duration: 0 }
        PauseAnimation { duration: 40 }
        NumberAnimation { target: skin; property: "jolt"; to: 0; duration: 0 }
    }
    Timer {
        interval: 4200
        repeat: true
        running: skin.playing && skin.lightMotion && !skin.blankLabel
        onTriggered: skin.glitch()
    }

    Item {
        id: hud
        x: skin.margin
        y: skin.margin
        width: skin.u
        height: skin.panelH

        transform: [
            Tilt { target: hud; amount: light.lightX; degrees: 8 },
            Tilt { target: hud; amount: light.lightY; degrees: 8; vertical: true }
        ]

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: skin.yellow
            shadowBlur: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: light.following ? 0.7 : 0.25 + 0.45 * skin.audioLevel
            Behavior on shadowOpacity { NumberAnimation { duration: 220 } }
        }

        Chamfer { anchors.fill: parent; cut: skin.cut; fill: skin.yellow }
        Chamfer {
            anchors.fill: parent
            anchors.margins: skin.line
            cut: skin.cut - skin.line * 0.4
            fill: skin.panel
        }

        // Header.
        Text {
            x: skin.pad
            y: skin.pad * 0.8
            text: "NOW//SPINNING"
            color: skin.yellow
            font { family: "monospace"; pixelSize: Math.max(7, Math.round(skin.u * 0.05)) }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: skin.pad
            y: skin.pad * 0.8
            visible: !skin.blankLabel
            text: skin.playing ? "● LIVE" : "■ HOLD"
            color: skin.cyan
            font { family: "monospace"; pixelSize: Math.max(7, Math.round(skin.u * 0.05)) }
            SequentialAnimation on opacity {
                running: skin.playing
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.25; duration: 0 }
                PauseAnimation { duration: 500 }
                NumberAnimation { to: 1; duration: 0 }
                PauseAnimation { duration: 700 }
            }
        }

        // The cover.
        Item {
            id: screen
            x: skin.pad
            y: skin.pad + skin.u * 0.09
            width: skin.u - 2 * skin.pad
            height: Math.round(width * 0.86)
            clip: true

            Rectangle { anchors.fill: parent; color: "#07080c" }

            // Drawn three times: the whole picture, then two bands of it
            // thrown the other way during a glitch.
            Repeater {
                model: [
                    { top: 0, bottom: 1, dir: 1 },
                    { top: 0.22, bottom: 0.38, dir: -1.6 },
                    { top: 0.61, bottom: 0.72, dir: -1 }
                ]
                Item {
                    required property var modelData
                    visible: !skin.blankLabel && (modelData.dir === 1 || skin.jolt !== 0)
                    y: screen.height * modelData.top
                    width: screen.width
                    height: screen.height * (modelData.bottom - modelData.top)
                    clip: true
                    Image {
                        x: skin.jolt * modelData.dir * skin.u * 0.04
                        y: -parent.y
                        width: screen.width
                        height: screen.height
                        source: skin.blankLabel ? "" : skin.artUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize { width: 400; height: 400 }
                        asynchronous: true
                    }
                }
            }

            // Scanlines.
            Repeater {
                model: Math.ceil(screen.height / 3)
                Rectangle {
                    required property int index
                    y: index * 3
                    width: screen.width
                    height: 1
                    color: Qt.rgba(0, 0, 0, 0.25)
                }
            }

            // The scan bar.
            Rectangle {
                visible: !skin.blankLabel
                width: screen.width
                height: Math.max(3, skin.u * 0.035)
                color: Qt.rgba(skin.cyan.r, skin.cyan.g, skin.cyan.b, light.following ? 0.45 : 0.3)
                y: -height
                NumberAnimation on y {
                    running: skin.playing && skin.lightMotion && !skin.blankLabel
                    loops: Animation.Infinite
                    from: -skin.u * 0.04
                    to: screen.height
                    duration: 2600
                }
            }

            // Cut corners, in the panel's colour.
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    readonly property real c: skin.u * 0.07
                    width: c * 1.42
                    height: width
                    rotation: 45
                    color: skin.panel
                    x: index === 0 ? screen.width - width / 2 : -width / 2
                    y: index === 0 ? -height / 2 : screen.height - height / 2
                }
            }

            Rectangle {
                visible: !skin.blankLabel
                x: skin.u * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: skin.u * 0.04
                width: sig.implicitWidth + skin.u * 0.04
                height: sig.implicitHeight + skin.u * 0.01
                color: Qt.rgba(0.03, 0.03, 0.05, 0.85)
                Text {
                    id: sig
                    anchors.centerIn: parent
                    text: "SIG " + (skin.playing ? "98" : "--") + "%"
                    color: skin.pink
                    font { family: "monospace"; pixelSize: Math.max(6, Math.round(skin.u * 0.042)) }
                }
            }
        }

        Text {
            x: skin.pad
            y: screen.y + screen.height + skin.u * 0.04
            width: screen.width
            visible: !skin.blankLabel
            text: skin.title.toUpperCase()
            elide: Text.ElideRight
            color: "#f2f2f2"
            font { family: "monospace"; pixelSize: Math.max(8, Math.round(skin.u * 0.075)); weight: Font.Bold }
        }
        Text {
            x: skin.pad
            y: screen.y + screen.height + skin.u * 0.135
            width: screen.width
            visible: !skin.blankLabel && skin.artist !== ""
            text: "ARTIST // " + skin.artist.toUpperCase()
            elide: Text.ElideRight
            color: skin.cyan
            font { family: "monospace"; pixelSize: Math.max(6, Math.round(skin.u * 0.048)) }
        }

        // The progress, in segments.
        Row {
            id: bar
            x: skin.pad
            y: hud.height - skin.pad - height - skin.u * 0.02
            visible: !skin.blankLabel
            spacing: Math.max(1, skin.u * 0.012)
            readonly property int count: 18
            // How many are lit: the segments only hear about it when one
            // more lights up, not on every tick of progress.
            readonly property int lit: Math.round(skin.progress * count)
            Repeater {
                model: bar.count
                Rectangle {
                    required property int index
                    width: (screen.width - (bar.count - 1) * bar.spacing) / bar.count
                    height: Math.max(3, skin.u * 0.035)
                    color: index < bar.lit ? skin.yellow : Qt.rgba(1, 1, 1, 0.12)
                }
            }
        }
    }
}
