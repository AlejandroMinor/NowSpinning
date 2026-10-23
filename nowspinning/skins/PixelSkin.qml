// Skin: the cover pixelated, loaded tiny and scaled up without smoothing.
//
// Ported from HyprFlow's media panel skins. The back, for the track info,
// is the empty grid.
//
// See VinylSkin.qml for the skin contract.
import QtQuick
import Quickshell.Widgets

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property bool blankLabel: false
    property int pixels: 64  // squares a side

    readonly property bool supportsFullArt: false
    property bool artFull: false
    readonly property real boxFactor: 1
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    implicitWidth: size
    implicitHeight: size

    ClippingRectangle {
        anchors.fill: parent
        radius: skin.size * 0.06
        color: "#1b1d22"
        Image {
            anchors.fill: parent
            source: skin.blankLabel ? "" : skin.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize { width: skin.pixels; height: skin.pixels }
            smooth: false
            asynchronous: true
        }
    }
}
