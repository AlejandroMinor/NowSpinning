// Skin: the bare CD, no case.
//
// Structurally the vinyl skin, with a CD in place of the record: same
// DiscFace underneath, no tonearm. See VinylSkin.qml for the skin contract;
// this one implements the same subset of it, minus `showArm`.
//
// Everything that makes the disc a CD rather than a record lives in
// parts/CdDisc.qml, shared with the cased skin.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false

    // A CD really does spin fast. Same default as the cased skin: they're
    // the same object.
    property real spinDegreesPerSecond: 30

    // A CD's printed face already carries the art nearly edge to edge, which
    // is what a real one looks like, so there's no larger size to grow into.
    readonly property bool supportsFullArt: false
    property bool artFull: false

    // Back side: an unprinted disc for the track info to sit on.
    property bool blankLabel: false

    readonly property real boxFactor: 1.02
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

    CdDisc {
        anchors.centerIn: parent
        size: skin.size
        artUrl: skin.artUrl
        angle: spin.angle
        blank: skin.blankLabel
    }
}
