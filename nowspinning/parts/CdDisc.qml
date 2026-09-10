// A CD, drawn: the printed face plus the rainbow sheen that sits over it.
//
// Shared by both CD skins, the bare disc and the one peeking out of a jewel
// case, so the two can't drift apart: it's the same object seen two ways.
// Everything here is what tells a CD apart from a vinyl record; the geometry
// itself lives in DiscFace.
import QtQuick

Item {
    id: cd

    property int size: 170
    property string artUrl: ""
    property real angle: 0

    // Unprinted disc. A real CD's data side is bright silver, but whatever
    // gets drawn over it (the track info card) is white text, so this goes
    // dark instead. The sheen staying on top is what still reads as a CD.
    property bool blank: false

    // On DiscFace's 1000-unit canvas, not in pixels.
    readonly property int holeRadius: 62

    implicitWidth: size
    implicitHeight: size

    DiscFace {
        anchors.centerIn: parent
        size: cd.size
        rotation: cd.angle

        // The printed side, not the reflective one: it's the one that
        // carries the cover art, and that asymmetry is what actually gives
        // away that the disc is spinning. The concentric grooves alone
        // don't do it: a rotated circle is the same circle.
        artUrl: cd.artUrl
        labelSize: 940
        labelPlaceholder: cd.blank ? "#1b1e26" : "#aeb6c4"
        holeRadius: cd.holeRadius

        bodyColor: "#b9c1cf"
        rimColor: "#e9edf4"
        rimWidth: 3

        // Data tracks: many more of them, and much fainter than a vinyl
        // groove.
        grooveInner: 200
        grooveOuter: 486
        grooveStep: 6
        grooveLight: Qt.rgba(1, 1, 1, 0.16)
        grooveAccent: Qt.rgba(1, 1, 1, 0.30)
        grooveAccentEvery: 10
        grooveDark: Qt.rgba(0, 0, 0, 0.10)

        // A CD has no visible track boundaries.
        bandRadii: []

        labelEdge: Qt.rgba(1, 1, 1, 0.45)
        labelInner: Qt.rgba(1, 1, 1, 0.30)
        holeEdge: Qt.rgba(0, 0, 0, 0.20)
        holeRim: Qt.rgba(1, 1, 1, 0.55)
    }

    // Same conical highlight as the vinyl skin, with different colors: on a
    // CD the light splits into a spectrum instead of just reflecting. Pushed
    // noticeably brighter/more opaque than the vinyl one, with a near-white
    // hot core at its peak: over a plain disc the subtler version read fine,
    // but it all but disappeared against a busy, colorful cover.
    Sheen {
        anchors.centerIn: parent
        width: cd.size
        height: cd.size

        // Held back on the blank disc: at full strength it's competing with
        // the text drawn over it, which a printed cover never has to deal
        // with.
        opacity: cd.blank ? 0.45 : 1
        holeRadius: cd.size * cd.holeRadius / 1000
        startAngle: 200

        sweep: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
            GradientStop { position: 0.08; color: Qt.rgba(0.30, 0.85, 1.00, 0.55) }
            GradientStop { position: 0.14; color: Qt.rgba(0.95, 0.98, 1.00, 0.92) }
            GradientStop { position: 0.20; color: Qt.rgba(0.55, 0.40, 1.00, 0.68) }
            GradientStop { position: 0.30; color: Qt.rgba(1.00, 0.35, 0.80, 0.62) }
            GradientStop { position: 0.40; color: Qt.rgba(1.00, 0.80, 0.25, 0.58) }
            GradientStop { position: 0.50; color: Qt.rgba(0.35, 1.00, 0.60, 0.62) }
            GradientStop { position: 0.60; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
            GradientStop { position: 1.00; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
        }
    }
}
