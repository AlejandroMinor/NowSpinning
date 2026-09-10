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

    readonly property real boxFactor: showArm ? arm.boxFactor : 1.02
    readonly property rect faceRect: Qt.rect((width - size) / 2,
                                             (height - size) / 2, size, size)
    readonly property bool faceIsCircle: true

    implicitWidth: Math.round(size * boxFactor)
    implicitHeight: implicitWidth

    SpinDriver {
        id: spin
        playing: skin.playing
        degreesPerSecond: skin.spinDegreesPerSecond
    }

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
        width: skin.size
        height: skin.size
        anchors.centerIn: parent
        holeRadius: skin.size * disc.holeRadius / disc.canvas
    }

    Tonearm {
        id: arm
        visible: skin.showArm
        discSize: skin.size
        down: skin.playing
        z: 1
    }
}
