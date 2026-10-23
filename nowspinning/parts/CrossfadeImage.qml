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
        const active = activeSlot === 0 ? img0 : img1;
        const incoming = activeSlot === 0 ? img1 : img0;

        // Nothing to show: both slots fade out (see their `opacity`), so a
        // track without art never inherits the previous track's cover.
        if (source === "") {
            settled();
            return;
        }

        // Changed away and straight back before the other cover finished
        // loading: what's on top is already right.
        if (active.source.toString() === source && active.status === Image.Ready) {
            settled();
            return;
        }

        // Back to the previous track: the slot underneath still holds its
        // cover. Assigning a `source` an Image already has is a no-op, no
        // status change ever fires, and it would never get swapped in, so
        // swap it in here instead. That was the "cover from the wrong song"
        // bug: A -> B -> A kept showing B.
        if (incoming.source.toString() === source && incoming.status === Image.Ready) {
            activeSlot = activeSlot === 0 ? 1 : 0;
            settled();
            return;
        }

        incoming.source = source;
    }

    Image {
        id: img0
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.sourceWidth
        sourceSize.height: root.sourceHeight
        asynchronous: true
        cache: true
        opacity: (status === Image.Ready && root.activeSlot === 0 && root.source !== "") ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.fadeDuration; easing.type: Easing.InOutQuad }
        }
        onStatusChanged: {
            // A load that finishes after `source` has already moved on is
            // stale: it doesn't get to take over.
            if (source.toString() !== root.source)
                return;
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
        opacity: (status === Image.Ready && root.activeSlot === 1 && root.source !== "") ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.fadeDuration; easing.type: Easing.InOutQuad }
        }
        onStatusChanged: {
            if (source.toString() !== root.source)
                return;
            const wasIncoming = root.activeSlot !== 1;
            if (status === Image.Ready) root.activeSlot = 1;
            if (wasIncoming && (status === Image.Ready || status === Image.Error))
                root.settled();
        }
    }
}
