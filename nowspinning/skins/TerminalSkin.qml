// Skin: what's playing, as the output of a command in a terminal window.
//
// The prompt types out `now-playing` on each new track, then the
// output comes in: the cover in a few green pixels, the title, the artist,
// whether it's playing, and the progress as a bar of hashes. It keeps
// running while the track plays, so there's no prompt under it; pausing
// suspends it (^Z, Stopped) and a fresh prompt blinks underneath.
//
// Under the pointer the window turns toward it and the command runs again.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is a cleared terminal.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist`, `progress` and `trackChangeToken`.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
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
    property bool lightMotion: true   // the cursor blinking
    property bool lightTilt: true     // the window turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property color ink: "#7dff9b"
    readonly property color amber: "#ffb454"

    implicitWidth: Math.round(size * 1.2)
    implicitHeight: size

    readonly property real boxFactor: implicitWidth / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Laid out on a 240 x 200 grid, scaled to the size.
    readonly property real u: implicitWidth / 240
    readonly property int fontPx: Math.max(6, Math.round(10 * u))

    FileView { id: hostname; path: "/etc/hostname" }
    readonly property string prompt: (Quickshell.env("USER") || "user") + "@"
        + (hostname.text().trim() || "localhost") + " $ "

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
        onFollowingChanged: if (following) skin.run()
    }

    // Typing the command: how many of its characters are out. The output
    // shows once it's all there.
    readonly property string command: "now-playing"
    property int typed: command.length
    readonly property bool done: typed >= command.length
    function run() {
        if (!blankLabel)
            typing.restart();
    }
    onTrackChangeTokenChanged: run()
    NumberAnimation {
        id: typing
        target: skin
        property: "typed"
        from: 0
        to: skin.command.length
        duration: 1100
    }

    property bool blink: true
    Timer {
        interval: 530
        repeat: true
        running: skin.lightMotion
        onTriggered: skin.blink = !skin.blink
        onRunningChanged: if (!running) skin.blink = true
    }
    readonly property string cursor: blink ? "█" : ""

    Rectangle {
        id: term
        anchors.fill: parent
        radius: 8 * skin.u
        color: "#0b0e0b"
        border { width: 1; color: "#2a3a2a" }

        transform: [
            Tilt { target: term; amount: light.lightX; degrees: 7 },
            Tilt { target: term; amount: light.lightY; degrees: 7; vertical: true }
        ]

        // Title bar.
        Rectangle {
            width: parent.width
            height: 20 * skin.u
            radius: term.radius
            color: "#1a1f1a"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: parent.color }
            Row {
                x: 8 * skin.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * skin.u
                Repeater {
                    model: ["#ff5f57", "#febc2e", "#28c840"]
                    Rectangle {
                        required property string modelData
                        width: 8 * skin.u
                        height: width
                        radius: width / 2
                        color: modelData
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: "~/music"
                color: "#6b7a6b"
                font { family: "monospace"; pixelSize: Math.max(5, Math.round(9 * skin.u)) }
            }
        }

        // The command line.
        Text {
            x: 10 * skin.u
            y: 28 * skin.u
            width: parent.width - 20 * skin.u
            elide: Text.ElideRight
            text: skin.prompt + (skin.blankLabel ? "clear" : skin.command.slice(0, skin.typed))
                + (skin.done ? "" : skin.cursor)
            color: skin.ink
            font { family: "monospace"; pixelSize: skin.fontPx }
        }

        // The output.
        Item {
            anchors.fill: parent
            visible: skin.done && !skin.blankLabel

            ClippingRectangle {
                x: 10 * skin.u
                y: 48 * skin.u
                width: 72 * skin.u
                height: width
                radius: 2 * skin.u
                color: "black"
                Image {
                    anchors.fill: parent
                    source: skin.blankLabel ? "" : skin.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize { width: 24; height: 24 }
                    smooth: false
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect { colorization: 0.55; colorizationColor: skin.ink }
                }
            }

            Column {
                x: 92 * skin.u
                y: 50 * skin.u
                width: term.width - x - 10 * skin.u
                spacing: 3 * skin.u
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "title  " + skin.title
                    color: skin.ink
                    font { family: "monospace"; pixelSize: skin.fontPx }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "artist " + skin.artist
                    color: skin.ink
                    font { family: "monospace"; pixelSize: skin.fontPx }
                }
                Text {
                    text: "state  " + (skin.playing ? "playing" : "paused")
                    color: skin.playing ? skin.ink : skin.amber
                    font { family: "monospace"; pixelSize: skin.fontPx }
                }
            }

            Text {
                x: 10 * skin.u
                y: 132 * skin.u
                readonly property int cells: 22
                readonly property int filled: Math.round(Math.max(0, Math.min(1, skin.progress)) * cells)
                text: "[" + "#".repeat(filled) + "-".repeat(cells - filled) + "] "
                    + Math.round(skin.progress * 100) + "%"
                color: skin.ink
                font { family: "monospace"; pixelSize: skin.fontPx }
            }

            // While it plays the command is still running, so there's no
            // prompt yet. Paused, it's been suspended with ^Z, and the
            // shell takes over.
            Column {
                x: 10 * skin.u
                y: 150 * skin.u
                visible: !skin.playing
                spacing: 1 * skin.u
                Text {
                    text: "^Z"
                    color: skin.ink
                    font { family: "monospace"; pixelSize: skin.fontPx }
                }
                Text {
                    text: "[1]+  Stopped    " + skin.command
                    color: skin.amber
                    font { family: "monospace"; pixelSize: skin.fontPx }
                }
                Text {
                    text: skin.prompt + skin.cursor
                    color: skin.ink
                    font { family: "monospace"; pixelSize: skin.fontPx }
                }
            }
        }
    }
}
