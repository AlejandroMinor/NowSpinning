// Skin: vinyl record with a tonearm.
//
// Almost everything visible here lives in parts/: this file only picks the
// numbers that make a round disc read as a vinyl record instead of a CD.
//
// SKIN CONTRACT (what shell.qml expects from any file in skins/):
//
//   property int    size          size of the main element, in px
//   property string artUrl        cover art to display
//   property bool   playing       whether playback is active
//
//   readonly property real boxFactor
//                                 how much space the skin needs around it,
//                                 as a multiple of `size`. 1.0 = just the
//                                 element itself.
//   readonly property rect faceRect
//                                 where the main face sits inside the skin.
//                                 Drives the mouse hit area and the controls
//                                 overlay.
//   readonly property bool faceIsCircle
//                                 whether that face is round or rectangular.
//
//   implicitWidth / implicitHeight = size * boxFactor
//
// Optional. If a skin doesn't declare these, the window simply doesn't use
// them:
//
//   property real spinDegreesPerSecond
//   property bool showArm
//   property bool showDeck                the turntable under the record
//   property bool blankLabel              large, unprinted label, for text to
//                                         be drawn over it (used by the back
//                                         side / track info card)
//   readonly property bool supportsFullArt
//   property bool artFull
//   readonly property bool handlesReveal  the skin knows how to show the
//                                         track info itself (e.g. sliding the
//                                         disc out of its case); otherwise
//                                         the window flips the whole skin and
//                                         paints the info on the back
//   property bool revealed                whether the track info is showing
//                                         right now (the window sets this)
//   property int trackChangeToken         bumped by the window on every real
//                                         track change, for a skin that wants
//                                         to react (e.g. the CD's swap-in)
//   property real progress                0..1 of the current track, for a
//                                         skin that shows it on the object
//                                         itself (the cassette's tape)
//   property color accent                 a color picked out of the cover art,
//                                         or white when there isn't one
//   property string title                 the track's title, for a skin that
//                                         writes it on the object (the Polaroid)
//   property var player                   the MprisSource, for a skin with
//                                         working controls of its own
//   readonly property bool ownTransport   it has its own transport keys, so the
//                                         overlay leaves its buttons out
//   function ownsPoint(x, y)              whether a tap there (skin coordinates)
//                                         is one of its own keys, which then
//                                         doesn't also flip the widget
//   readonly property bool solidBox       the whole box is the object, not just
//                                         the face: it's grabbed and hidden as
//                                         a rectangle (the vinyl's turntable)
//
// The skin draws itself centered on itself and only animates based on
// `playing`. The window, dragging, hover, and the controls overlay are none
// of its concern.
//
// The disc's proportions come from reading github.com/yappologistic/Spun
// (src/disc.cpp) as a visual reference only. None of its code lives here:
// that project is C++ over QPainter under the PolyForm Noncommercial
// license. This is QML written from scratch.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false

    property real spinDegreesPerSecond: 9

    // The tonearm is optional. Off by default: the disc alone reads cleaner.
    property bool showArm: false

    // The whole turntable under the record: plinth, platter, speed keys.
    // Off by default too; it makes the widget a good deal wider.
    property bool showDeck: false

    // Drives the arm across the record as the track plays.
    property real progress: 0

    // Tints the platter and the speed light.
    property color accent: "white"

    // A vinyl record does NOT offer full-face cover art: with the art
    // covering the whole disc it stops reading as vinyl and starts looking
    // like a CD. The machinery for it lives in DiscFace and works fine; this
    // just declares that this skin doesn't use it.
    readonly property bool supportsFullArt: false
    property bool artFull: false

    // Large, unprinted label, like a white-label promo disc. Used by the
    // back side: it leaves room for text while keeping the grooves visible
    // around it.
    property bool blankLabel: false

    readonly property real r: size / 2

    // Room around the plinth for its shadow, in disc radii.
    readonly property real pad: 0.10

    // Without the deck the skin is a square around the disc. With it, the
    // box is the plinth plus its shadow, and the disc sits left of center.
    readonly property real boxW: showDeck
        ? (deck.edgeLeft + deck.edgeRight + 2 * pad) * r
        : size * (showArm ? arm.boxFactor : 1.02)
    readonly property real boxH: showDeck
        ? (deck.edgeTop + deck.edgeBottom + 2 * pad) * r
        : boxW
    readonly property real boxFactor: Math.max(boxW, boxH) / size

    readonly property real discX: showDeck ? (deck.edgeLeft + pad) * r : width / 2
    readonly property real discY: showDeck ? (deck.edgeTop + pad) * r : height / 2

    readonly property rect faceRect: Qt.rect(discX - size / 2, discY - size / 2, size, size)
    readonly property bool faceIsCircle: true
    readonly property bool solidBox: showDeck

    implicitWidth: Math.round(boxW)
    implicitHeight: Math.round(boxH)

    SpinDriver {
        id: spin
        playing: skin.playing
        degreesPerSecond: skin.spinDegreesPerSecond
    }

    TurntableDeck {
        id: deck
        anchors.fill: parent
        visible: skin.showDeck
        discSize: skin.size
        cx: skin.discX
        cy: skin.discY
        angle: spin.angle
        playing: skin.playing
        accent: skin.accent
    }

    // Square around the disc's center: the arm places itself against it.
    Item {
        x: skin.discX - width / 2
        y: skin.discY - height / 2
        width: skin.size
        height: skin.size

        DiscFace {
            id: disc

            anchors.centerIn: parent
            size: skin.size
            artUrl: skin.artUrl
            rotation: spin.angle

            labelSize: skin.artFull ? 952 : (skin.blankLabel ? 720 : 396)
            Behavior on labelSize {
                NumberAnimation { duration: 420; easing.type: Easing.InOutCubic }
            }
        }

        Sheen {
            anchors.fill: parent
            holeRadius: skin.size * disc.holeRadius / disc.canvas
        }

        // On the deck the arm gets a proper bearing, set further out so it
        // clears the platter: longer, and resting off to the side.
        Tonearm {
            id: arm
            visible: skin.showArm
            discSize: skin.size
            down: skin.playing
            progress: skin.progress
            showBase: skin.showDeck
            baseRing: deck.platterMetal
            pivotDistance: skin.showDeck ? 1.30 : 1.02
            length: skin.showDeck ? 1.22 : 0.97
            restRadius: skin.showDeck ? 1.20 : 1.06
            z: 1
        }
    }
}
