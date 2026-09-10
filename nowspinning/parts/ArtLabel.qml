// The album cover, cropped to a circle, with the disc's center hole left
// unpainted so the desktop shows through it, like on a real disc.
import QtQuick
import QtQuick.Effects

Item {
    id: label

    property string artUrl: ""
    property real holeRadius: 16          // same units as width
    property color placeholder: "#1c1c22"

    // Shown while the cover art is still downloading, so there's never a
    // frame with an empty center.
    Ring {
        anchors.fill: parent
        outerRadius: width / 2
        innerRadius: label.holeRadius
        color: label.placeholder
    }

    // Crossfades between covers on its own; see CrossfadeImage.qml for why
    // a plain Image isn't enough.
    CrossfadeImage {
        id: art
        anchors.fill: parent
        source: label.artUrl
        visible: false
        layer.enabled: true
    }

    Ring {
        id: mask
        anchors.fill: parent
        outerRadius: width / 2
        innerRadius: label.holeRadius
        color: "black"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: art
        maskEnabled: true
        maskSource: mask
        visible: art.ready
    }
}
