// A cover image that crossfades into whatever `source` changes to, instead
// of popping the instant the new one finishes loading.
//
// Two Image elements swap which one is on top. The other one quietly loads
// the next `source` in the background, and only takes over once it's
// actually ready, fading in while the old one fades out.
import QtQuick

Item {
    id: root

    property string source: ""
    property int sourceWidth: 512
    property int sourceHeight: 512
    property int fadeDuration: 280

    // Which slot is currently on top. Flips to whichever slot just finished
    // loading the newest `source`.
    property int activeSlot: 0

    // True only once the *currently requested* source is showing: a failed
    // or still-loading source leaves the old one active (and Ready), so
    // the active slot's status alone isn't enough to tell.
    readonly property bool ready: {
        const active = activeSlot === 0 ? img0 : img1;
        return active.source.toString() === root.source
            && active.status === Image.Ready;
    }

    // Fires once per `source` change, when the incoming image has settled
    // one way or another: loaded, failed, or (an empty source never loads
    // at all) immediately. Lets a listener react to "this source is as
    // done as it's going to get" without polling `ready`.
    signal settled()

    onSourceChanged: {
        const incoming = activeSlot === 0 ? img1 : img0;
        incoming.source = source;
        if (source === "")
            settled();
    }

    Image {
        id: img0
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.sourceWidth
        sourceSize.height: root.sourceHeight
        asynchronous: true
        cache: true
        opacity: (status === Image.Ready && root.activeSlot === 0) ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.fadeDuration; easing.type: Easing.InOutQuad }
        }
        onStatusChanged: {
            const wasIncoming = root.activeSlot !== 0;
            if (status === Image.Ready) root.activeSlot = 0;
            if (wasIncoming && (status === Image.Ready || status === Image.Error))
                root.settled();
        }
    }

    Image {
        id: img1
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.sourceWidth
        sourceSize.height: root.sourceHeight
        asynchronous: true
        cache: true
        opacity: (status === Image.Ready && root.activeSlot === 1) ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.fadeDuration; easing.type: Easing.InOutQuad }
        }
        onStatusChanged: {
            const wasIncoming = root.activeSlot !== 1;
            if (status === Image.Ready) root.activeSlot = 1;
            if (wasIncoming && (status === Image.Ready || status === Image.Error))
                root.settled();
        }
    }
}
