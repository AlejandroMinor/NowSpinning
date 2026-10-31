// Skin: the cover as a Polaroid, the title written under it in marker. A new
// track drops a new photo on top of the last one, tilted the other way, and
// the pile keeps the last few tracks' photos, each where it fell: what's
// been playing, at a glance.
//
// Ported from HyprFlow's media panel skins. The back, for the track info,
// is the photo turned over: blank, dark enough for the white text.
//
// The front photo sways a little while playing and turns toward the
// pointer, with a glare sliding across its glossy print. The one under it
// stays flat on the table.
//
// Options: showStack (the pile under the photo), stackDepth (how many
// photos it keeps, 3 or 1), lightMotion (the sway on its own) and
// lightTilt (turning toward the pointer).
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`.
import QtQuick
import QtQuick.Effects
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property bool blankLabel: false
    property bool showStack: true  // the last photos peeking out underneath
    property int stackDepth: 3     // how many of them
    // The last track's cover and title, from whoever outlives the skin: a
    // skin made again (a panel reopened) starts its stack with them.
    property string previousArt: ""
    property string previousTitle: ""
    property bool lightMotion: true  // the front photo swaying on its own
    property bool lightTilt: true    // the front photo turning toward the pointer

    FontLoader { id: marker; source: Qt.resolvedUrl("../fonts/PermanentMarker-Regular.ttf") }

    readonly property real frameWidth: size * 0.8
    readonly property real pad: frameWidth * 0.06
    readonly property real photo: frameWidth - 2 * pad
    readonly property real frameHeight: pad + photo + frameWidth * 0.24
    property real tilt: 3

    // With more than one photo in the pile they fan out behind the front
    // one, up and to the sides, far enough to make out each cover: the box
    // grows for them, and the front photo sits a little low in it.
    readonly property bool fanned: showStack && stackDepth > 1
    readonly property real lowered: fanned ? size * 0.06 : 0

    implicitWidth: Math.round(size * (fanned ? 1.32 : 1))
    implicitHeight: Math.round(frameHeight * (fanned ? 1.3 : 1.12))

    readonly property bool supportsFullArt: false
    property bool artFull: false
    readonly property real boxFactor: implicitHeight / size
    // The front photo, untilted. Close enough for the hit area and the
    // overlay; the few degrees of tilt stay inside the box.
    readonly property rect faceRect: Qt.rect((width - frameWidth) / 2,
                                             (height - frameHeight) / 2 + lowered,
                                             frameWidth, frameHeight)
    readonly property bool faceIsCircle: false
    // The photos draw their own.
    readonly property bool ownShadow: true
    // The photo underneath sticks out past the face.
    readonly property bool solidBox: true

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: skin.lightMotion
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // The photos under the front one, the last track's first. Each keeps
    // where it fell: one photo alone peeks out a little more turned than it
    // was on top; fanned, each takes the next of three places (right, left,
    // top) and stays there as others land, the one leaving the pile freeing
    // its place for the next.
    property var pile: []
    readonly property int pileMax: 3
    property int dropped: 0
    readonly property var fan: [{ dx: 0.17, dy: -0.05, rotation: 8 },
                                { dx: -0.17, dy: -0.03, rotation: -9 },
                                { dx: 0.01, dy: -0.13, rotation: 3 }]
    function lay(art, caption) {
        pile = [{ art: art, caption: caption, rotation: front.rotation * 1.6, place: dropped % fan.length }]
            .concat(pile.slice(0, pileMax - 1));
        dropped += 1;
    }
    function drop() {
        // The title can change before the cover, so the caption comes from
        // previousTitle when there is one.
        if (front.art)
            lay(front.art, previousTitle || front.caption);
        else if (previousArt)
            lay(previousArt, previousTitle);
        tilt = -tilt;
        front.art = artUrl;
        dropIn.restart();
    }
    onArtUrlChanged: if (!blankLabel) drop()
    // Handed over after the cover (the order bindings land in isn't ours to
    // pick): an empty stack still takes it.
    onPreviousArtChanged: {
        if (pile.length === 0 && previousArt && previousArt !== front.art)
            lay(previousArt, previousTitle);
    }

    component Photo: Item {
        property string art
        property string caption
        property bool glossy: false
        width: skin.frameWidth
        height: skin.frameHeight
        x: (skin.width - width) / 2
        y: (skin.height - height) / 2 + skin.lowered
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
            clip: true
            Image {
                anchors.fill: parent
                source: parent.parent.art
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 300; height: 300 }
                asynchronous: true
            }
            // Glare on the print, slid across by the light.
            Rectangle {
                visible: parent.parent.glossy
                width: skin.photo * 0.5
                height: skin.photo * 3
                x: skin.photo * 0.25 + light.lightX * skin.photo * 0.8
                y: -skin.photo + light.lightY * skin.photo * 0.3
                rotation: 32
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.22) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
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

    // Deepest first, so the last track's lands on top of the pile.
    Repeater {
        model: skin.showStack ? skin.pile.slice(0, Math.max(1, skin.stackDepth)).reverse() : []
        Photo {
            required property var modelData
            readonly property var place: skin.fanned ? skin.fan[modelData.place]
                : { dx: 0, dy: 0, rotation: modelData.rotation }
            art: modelData.art
            caption: modelData.caption
            rotation: place.rotation
            x: (skin.width - width) / 2 + place.dx * skin.frameWidth
            y: (skin.height - height) / 2 + skin.lowered + place.dy * skin.frameWidth
        }
    }
    // On the back there's no cover to stack, but the pile is still there,
    // turned over with the rest.
    Photo {
        visible: skin.showStack && skin.blankLabel
        rotation: -skin.tilt * 1.6
    }
    Photo {
        id: front
        caption: skin.title
        rotation: skin.tilt
        glossy: true
        // Turns toward the light, a little less than the foil card: a
        // photo, not a card held up to it.
        transform: [
            Tilt { target: front; amount: light.lightX; degrees: 6 },
            Tilt { target: front; amount: light.lightY; degrees: 6; vertical: true }
        ]
    }

    ParallelAnimation {
        id: dropIn
        NumberAnimation { target: front; property: "y"; from: (skin.height - front.height) / 2 + skin.lowered - skin.size * 0.3; to: (skin.height - front.height) / 2 + skin.lowered; duration: 460; easing.type: Easing.OutBack }
        NumberAnimation { target: front; property: "opacity"; from: 0; to: 1; duration: 200 }
        NumberAnimation { target: front; property: "rotation"; from: skin.tilt * 4; to: skin.tilt; duration: 460; easing.type: Easing.OutCubic }
    }
}
