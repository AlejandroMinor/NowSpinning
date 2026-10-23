// Skin: a portable cassette player, with the cassette seen through its lid.
//
// The cassette is the cassette skin itself, untouched and scaled down to
// fit the window, so the tape still winds from reel to reel with the
// track. Around it: the player's metal body, a smoked glass lid, and a row
// of piano keys whose play key stays pressed in while playing.
//
// The keys work: rewind and fast forward skip tracks, play toggles, stop
// pauses. So the face, where the hover overlay goes, is only the window
// onto the cassette, and the overlay leaves its own transport buttons out.
//
// Flips like the vinyl skin to show the track info: the back is the same
// player with side B in it.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `progress`, `accent` and `player`, hands
// `shellOpacity` on to the cassette, and declares `ownTransport` and
// `ownsPoint`.
import QtQuick
import ".."

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property real progress: 0
    property color accent: "white"
    property real shellOpacity: 1
    property bool blankLabel: false

    // MprisSource, set by the window; the keys call straight into it.
    property var player: null
    readonly property bool ownTransport: true

    // Same as the bare cassette: it's the same tape turning.
    property real spinDegreesPerSecond: 40

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property real w: Math.round(size * 1.5)
    readonly property real h: Math.round(size * 1.24)

    readonly property real boxFactor: w / size
    readonly property rect faceRect: pane
    readonly property bool faceIsCircle: false
    // The face is just the window; the whole player is what gets grabbed
    // and hidden against an edge.
    readonly property bool solidBox: true

    implicitWidth: w
    implicitHeight: h

    readonly property bool tinted: !Qt.colorEqual(accent, "white")

    // The lid's window, and the keys below it.
    readonly property rect pane: Qt.rect(w * 0.05, h * 0.06, w * 0.90, h * 0.70)
    readonly property real keysY: h * 0.80
    readonly property real keysH: h * 0.15

    function ownsPoint(px, py) {
        return py >= keysY && py <= keysY + keysH
            && px >= keyRow.x && px <= keyRow.x + keyRow.width;
    }

    function press(kind) {
        if (!player)
            return;
        if (kind === "prev") player.previous();
        else if (kind === "next") player.next();
        else if (kind === "play") player.toggle();
        else if (kind === "stop" && player.playing) player.toggle();
    }

    // Body: brushed aluminum, darker at the edges.
    Rectangle {
        anchors.fill: parent
        radius: skin.w * 0.045
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#d4d8de" }
            GradientStop { position: 0.08; color: "#bfc4cb" }
            GradientStop { position: 0.92; color: "#a7adb5" }
            GradientStop { position: 1.00; color: "#8a9099" }
        }
        border.width: Math.max(1, skin.w * 0.006)
        border.color: "#6f757d"

        // Fine horizontal brushing.
        Repeater {
            model: 18
            Rectangle {
                required property int index
                x: parent.radius
                y: parent.height * (0.03 + index * 0.055)
                width: parent.width - 2 * parent.radius
                height: 1
                color: Qt.rgba(1, 1, 1, index % 2 ? 0.05 : 0.09)
            }
        }
    }

    // Accent stripe along the bottom, the one bit of color on the body.
    Rectangle {
        x: skin.w * 0.05
        y: skin.h * 0.775
        width: skin.w * 0.90
        height: Math.max(2, skin.h * 0.012)
        radius: height / 2
        color: skin.tinted ? skin.accent : "#c9533f"
        opacity: 0.85
    }

    // Lid frame and the dark recess the cassette sits in.
    Rectangle {
        x: skin.pane.x - skin.w * 0.012
        y: skin.pane.y - skin.w * 0.012
        width: skin.pane.width + skin.w * 0.024
        height: skin.pane.height + skin.w * 0.024
        radius: skin.w * 0.03
        color: "#2b2f35"
        antialiasing: true
    }

    Rectangle {
        x: skin.pane.x
        y: skin.pane.y
        width: skin.pane.width
        height: skin.pane.height
        radius: skin.w * 0.022
        color: "#14161a"
        antialiasing: true
    }

    // The cassette, sized to the window with a little room around it.
    CassetteSkin {
        id: tape
        readonly property real fit: Math.min(skin.pane.width * 0.94 / 1.417,
                                             skin.pane.height * 0.92 / 0.9)
        size: Math.round(fit)
        x: skin.pane.x + (skin.pane.width - width) / 2
        y: skin.pane.y + (skin.pane.height - height) / 2
        artUrl: skin.artUrl
        playing: skin.playing
        progress: skin.progress
        accent: skin.accent
        shellOpacity: skin.shellOpacity
        blankLabel: skin.blankLabel
        spinDegreesPerSecond: skin.spinDegreesPerSecond
    }

    // Smoked glass over it: a faint tint and a diagonal glare.
    Rectangle {
        x: skin.pane.x
        y: skin.pane.y
        width: skin.pane.width
        height: skin.pane.height
        radius: skin.w * 0.022
        antialiasing: true
        color: Qt.rgba(0.08, 0.10, 0.13, 0.18)
        border.width: Math.max(1, skin.w * 0.005)
        border.color: Qt.rgba(1, 1, 1, 0.10)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 0.70; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 0.78; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.86; color: Qt.rgba(1, 1, 1, 0.00) }
            }
        }
    }

    // Piano keys: rewind, play, fast forward, stop. Only play moves: it
    // stays pressed in for as long as the track plays.
    Row {
        id: keyRow
        x: skin.w * 0.05
        y: skin.keysY
        spacing: skin.w * 0.012

        Repeater {
            model: ["prev", "play", "next", "stop"]

            Item {
                id: key
                required property int index
                required property string modelData
                readonly property bool down: (modelData === "play" && skin.playing) || tap.pressed
                width: skin.w * 0.125
                height: skin.keysH

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: tap
                    onTapped: skin.press(key.modelData)
                }

                // The slot it travels in.
                Rectangle {
                    anchors.fill: parent
                    radius: skin.w * 0.012
                    color: "#3a3f46"
                    antialiasing: true
                }

                Rectangle {
                    x: 1
                    width: parent.width - 2
                    height: parent.height - 1 - (key.down ? skin.keysH * 0.22 : 0)
                    y: key.down ? skin.keysH * 0.22 : 0
                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    radius: skin.w * 0.012
                    antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: key.down ? "#8d939b" : "#e3e6ea" }
                        GradientStop { position: 1.0; color: key.down ? "#6c727a" : "#a9afb7" }
                    }

                    IconButton {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.75
                        height: width
                        visible: key.modelData !== "stop"
                        kind: key.modelData
                        tint: "#3c4148"
                        enabled: false
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: key.modelData === "stop"
                        width: Math.min(parent.width, parent.height) * 0.30
                        height: width
                        color: "#3c4148"
                    }
                }
            }
        }
    }

    // Volume wheel, at the right end of the key row, ridged.
    Item {
        x: skin.w * 0.80
        y: skin.keysY
        width: skin.w * 0.15
        height: skin.keysH

        Rectangle {
            anchors.fill: parent
            radius: skin.w * 0.012
            color: "#2e3238"
            antialiasing: true
            clip: true

            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    x: parent.width * (0.08 + index * 0.105)
                    y: parent.height * 0.15
                    width: Math.max(1, parent.width * 0.04)
                    height: parent.height * 0.70
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.10 + 0.25 * Math.sin(Math.PI * (index + 0.5) / 9))
                }
            }
        }
    }
}
