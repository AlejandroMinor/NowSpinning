// Skin: the cover as a holographic trading card.
//
// A rainbow foil sits over the art and slides across it, with a white glint
// riding along, while playing. Under the pointer the card tilts toward it
// and the foil follows the pointer instead, like turning a real one in the
// light. The title runs along a strip at the bottom.
//
// Rectangular face, so the window swaps the ring for the bar on its own.
// The back, for the track info, is the card's patterned back.
//
// Options: foilStyle (rainbow, gold, silver, art for a sweep around the
// cover's own colour, or a "#rrggbb" to sweep around; anything else falls
// back to the rainbow), foilMotion (the foil sliding on its own) and
// foilTilt (the card turning toward the pointer).
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title` and `accent`.
import QtQuick
import QtQuick.Effects

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property color accent: "white"
    property bool blankLabel: false

    // Options, bound to config keys of the same name by the window.
    property string foilStyle: "rainbow"  // rainbow | gold | silver | art | "#rrggbb"
    property bool foilMotion: true        // the foil sliding on its own
    property bool foilTilt: true          // the card turning toward the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    // A trading card's 63 x 88 mm.
    readonly property real cardW: Math.round(size * 0.86)
    readonly property real cardH: Math.round(cardW * 88 / 63)

    implicitWidth: Math.round(size * 0.98)
    implicitHeight: Math.round(cardH * 1.04)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect((width - cardW) / 2, (height - cardH) / 2, cardW, cardH)
    readonly property bool faceIsCircle: false
    // The card draws its own.
    readonly property bool ownShadow: true

    readonly property bool tinted: !Qt.colorEqual(accent, "white")

    // The foil's seven bands, by finish. "art" runs a hue sweep around the
    // cover's own colour, a "#rrggbb" one around that colour; anything else
    // falls back to the rainbow.
    function sweep(base) {
        const out = [];
        for (let i = 0; i < 7; i++)
            out.push(Qt.hsla((base.hslHue + (i - 3) * 0.06 + 1) % 1,
                             Math.max(0.5, base.hslSaturation), 0.62, 1));
        return out;
    }
    readonly property var bands: {
        if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(foilStyle))
            return sweep(Qt.color(foilStyle));
        if (foilStyle === "gold")
            return ["#fff1b8", "#e8b84a", "#ffd97a", "#b8862a", "#ffe9a0", "#d9a440", "#fff1b8"];
        if (foilStyle === "silver")
            return ["#ffffff", "#b9c2cc", "#eef2f6", "#8e98a3", "#f6f8fa", "#aab3bd", "#ffffff"];
        if (foilStyle === "art" && tinted)
            return sweep(accent);
        return ["#ff4d8a", "#ffb84d", "#f6ff4d", "#4dff9a", "#4dc7ff", "#8a5cff", "#ff4dd2"];
    }
    readonly property color trim: tinted ? accent : "#c9ced6"

    // Where the light hits, -1..1 across the card. Drifts on its own while
    // playing; follows the pointer while it's over the card.
    property real drift: 0
    SequentialAnimation on drift {
        running: skin.playing && skin.foilMotion && !(skin.foilTilt && hover.hovered)
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 3200; easing.type: Easing.InOutSine }
        NumberAnimation { to: -1; duration: 3200; easing.type: Easing.InOutSine }
    }
    readonly property bool following: foilTilt && hover.hovered
    readonly property real lightX: following
        ? Math.max(-1, Math.min(1, (hover.point.position.x - card.x) / card.width * 2 - 1)) : drift
    readonly property real lightY: following
        ? Math.max(-1, Math.min(1, (hover.point.position.y - card.y) / card.height * 2 - 1)) : 0

    HoverHandler { id: hover }

    Item {
        id: card
        x: (skin.width - skin.cardW) / 2
        y: (skin.height - skin.cardH) / 2
        width: skin.cardW
        height: skin.cardH

        // Tilts toward the light. Only a few degrees: more and the card
        // reads as falling over.
        transform: [
            Rotation {
                origin.x: card.width / 2; origin.y: card.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: skin.lightX * 9
                Behavior on angle { NumberAnimation { duration: 180 } }
            },
            Rotation {
                origin.x: card.width / 2; origin.y: card.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: -skin.lightY * 9
                Behavior on angle { NumberAnimation { duration: 180 } }
            }
        ]

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cardMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.5
            shadowBlur: 0.5
            shadowVerticalOffset: 3
        }

        // Card stock and trim.
        Rectangle {
            anchors.fill: parent
            color: skin.blankLabel ? "#1c2230" : Qt.darker(skin.trim, 1.1)
        }

        // Front: the art, inset in the trim, and the title strip.
        Item {
            anchors.fill: parent
            visible: !skin.blankLabel

            Rectangle {
                id: window
                x: skin.cardW * 0.06
                y: skin.cardW * 0.06
                width: skin.cardW * 0.88
                height: skin.cardH * 0.74
                color: "#15171b"
                clip: true

                Image {
                    anchors.fill: parent
                    source: skin.blankLabel ? "" : skin.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize { width: 400; height: 400 }
                    asynchronous: true
                }
            }

            Rectangle {
                x: window.x
                y: window.y + window.height + skin.cardH * 0.025
                width: window.width
                height: skin.cardH - y - skin.cardW * 0.06
                radius: skin.cardW * 0.02
                color: Qt.rgba(0, 0, 0, 0.55)

                Text {
                    anchors.fill: parent
                    anchors.margins: skin.cardW * 0.03
                    text: skin.title
                    color: "white"
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Math.max(8, Math.round(skin.cardW * 0.075))
                    font.weight: Font.Bold
                }
            }
        }

        // Back: a diamond pattern.
        Grid {
            anchors.centerIn: parent
            visible: skin.blankLabel
            columns: 6
            spacing: skin.cardW * 0.06
            Repeater {
                model: 48
                Rectangle {
                    width: skin.cardW * 0.07
                    height: width
                    rotation: 45
                    color: Qt.rgba(1, 1, 1, 0.07)
                }
            }
        }

        // The foil: rainbow bands, wider than the card, slid across it by
        // the light. Thin enough to keep the art readable underneath.
        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                width: card.width * 3
                height: card.height * 3
                x: -card.width + skin.lightX * card.width * 0.6
                y: -card.height + skin.lightY * card.height * 0.4
                rotation: 32
                opacity: skin.blankLabel ? 0.10 : 0.30
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.30; color: "transparent" }
                    GradientStop { position: 0.36; color: skin.bands[0] }
                    GradientStop { position: 0.40; color: skin.bands[1] }
                    GradientStop { position: 0.44; color: skin.bands[2] }
                    GradientStop { position: 0.48; color: skin.bands[3] }
                    GradientStop { position: 0.52; color: skin.bands[4] }
                    GradientStop { position: 0.56; color: skin.bands[5] }
                    GradientStop { position: 0.60; color: skin.bands[6] }
                    GradientStop { position: 0.66; color: "transparent" }
                }
            }

            // White glint riding along with it.
            Rectangle {
                width: card.width * 0.25
                height: card.height * 3
                x: card.width * 0.38 + skin.lightX * card.width * 0.7
                y: -card.height
                rotation: 32
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, skin.blankLabel ? 0.06 : 0.28) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }

        // Edge highlight.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Math.max(1, skin.cardW * 0.01)
            border.color: Qt.rgba(1, 1, 1, 0.25)
        }
    }

    Rectangle {
        id: cardMask
        width: skin.cardW
        height: skin.cardH
        radius: skin.cardW * 0.05
        color: "black"
        antialiasing: true
        visible: false
        layer.enabled: true
    }
}
