// Skin: the cover as a Polaroid, the title written under it in marker. A new
// track drops a new photo on top of the last one, tilted the other way.
//
// Ported from HyprFlow's media panel skins. The back, for the track info,
// is the photo turned over: blank, dark enough for the white text.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`.
import QtQuick
import QtQuick.Effects

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property bool blankLabel: false
    property bool showStack: true  // the last photo peeking out underneath
    // The last track's cover and title, from whoever outlives the skin: a
    // skin made again (a panel reopened) starts its stack with them.
    property string previousArt: ""
    property string previousTitle: ""

    FontLoader { id: marker; source: Qt.resolvedUrl("../fonts/PermanentMarker-Regular.ttf") }

    readonly property real frameWidth: size * 0.8
    readonly property real pad: frameWidth * 0.06
    readonly property real photo: frameWidth - 2 * pad
    readonly property real frameHeight: pad + photo + frameWidth * 0.24
    property real tilt: 3

    implicitWidth: size
    implicitHeight: Math.round(frameHeight * 1.12)

    readonly property bool supportsFullArt: false
    property bool artFull: false
    readonly property real boxFactor: implicitHeight / size
    // The front photo, untilted. Close enough for the hit area and the
    // overlay; the few degrees of tilt stay inside the box.
    readonly property rect faceRect: Qt.rect((width - frameWidth) / 2,
                                             (height - frameHeight) / 2,
                                             frameWidth, frameHeight)
    readonly property bool faceIsCircle: false
    // The photo underneath sticks out past the face.
    readonly property bool solidBox: true

    function drop() {
        // The title can change before the cover, so the caption comes from
        // previousTitle when there is one.
        if (front.art) {
            back.art = front.art;
            back.caption = previousTitle || front.caption;
        } else if (previousArt) {
            back.art = previousArt;
            back.caption = previousTitle;
        }
        tilt = -tilt;
        front.art = artUrl;
        dropIn.restart();
    }
    onArtUrlChanged: if (!blankLabel) drop()

    component Photo: Item {
        property string art
        property string caption
        width: skin.frameWidth
        height: skin.frameHeight
        x: (skin.width - width) / 2
        y: (skin.height - height) / 2
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowBlur: 0.5
            shadowOpacity: 0.45
            shadowVerticalOffset: 2
        }
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: skin.blankLabel ? "#2a2826" : "#f4f1ea"
        }
        Rectangle {
            x: skin.pad; y: skin.pad
            width: skin.photo; height: skin.photo
            color: "#202020"
            visible: !skin.blankLabel
            Image {
                anchors.fill: parent
                source: parent.parent.art
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 300; height: 300 }
                asynchronous: true
            }
        }
        Text {
            x: skin.pad
            width: skin.photo
            y: skin.pad + skin.photo + (skin.frameHeight - skin.pad - skin.photo - height) / 2
            text: skin.blankLabel ? "" : parent.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: "#2b2b2b"
            font { family: marker.name; pixelSize: skin.frameWidth * 0.085 }
        }
    }

    Photo {
        id: back
        visible: skin.showStack && art !== ""
        rotation: -skin.tilt * 1.6
    }
    Photo {
        id: front
        caption: skin.title
        rotation: skin.tilt
    }

    ParallelAnimation {
        id: dropIn
        NumberAnimation { target: front; property: "y"; from: (skin.height - front.height) / 2 - skin.size * 0.3; to: (skin.height - front.height) / 2; duration: 460; easing.type: Easing.OutBack }
        NumberAnimation { target: front; property: "opacity"; from: 0; to: 1; duration: 200 }
        NumberAnimation { target: front; property: "rotation"; from: skin.tilt * 4; to: skin.tilt; duration: 460; easing.type: Easing.OutCubic }
    }
}
