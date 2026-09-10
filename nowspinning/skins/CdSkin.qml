// Skin: CD jewel case with the cover art, and the disc peeking out behind it.
//
// The main face is the case, which is rectangular: that's why this skin
// declares `faceIsCircle: false`, and the window figures out the mouse hit
// area, the shape of the controls overlay, and the progress style on its own
// (a ring around a square face makes no sense, so it falls back to the bar).
//
// Opens itself (`handlesReveal`): instead of flipping like the vinyl skin, it
// slides the disc out of the case.
//
// The disc is the same `DiscFace` the vinyl skin uses, with different
// numbers: fine, low-contrast tracks, a silvery body, and a big, bright
// center hub.
//
// `peekSide` picks which edge of the case the disc pokes out from: right,
// left, top, or bottom. Right/left is how a real jewel case actually opens:
// flipping to "left" mirrors the whole case, spine included, so the disc
// never collides with it. Top/bottom don't correspond to any real jewel
// case (the spine is always vertical on a real one). Here the spine and
// its retention tabs simply rotate 90° to stay on the two edges away from
// the disc, which keeps the layout self-consistent even though no physical
// case actually opens that way.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170            // the case's side length
    property string artUrl: ""
    property bool playing: false

    property string peekSide: "right"   // "right" | "left" | "top" | "bottom"

    // A CD really does spin fast. Not as fast as a real one, but enough
    // that it's obviously moving.
    property real spinDegreesPerSecond: 30

    // The window sets this when it wants the track info card shown.
    readonly property bool handlesReveal: true
    property bool revealed: false

    // Bumped on a real track change (title), not a bare cover-art change.
    property int trackChangeToken: 0
    onTrackChangeTokenChanged: {
        swapping = true;
        swapArmed = true;
        maxWaitTimer.restart();
    }

    // Starts true: before the first track loads there's nothing to peek
    // out with, and the first real trackChangeToken bump reveals it the
    // same way any later track change does.
    property bool swapping: true

    // False until the first real swap starts, so the cover's `settled`
    // firing for its initial empty `artUrl` at cold start can't end a
    // reveal that hasn't begun yet.
    property bool swapArmed: false

    // Art is fetched over the network, not read from disk: if it never
    // resolves, don't leave the disc centered forever.
    Timer {
        id: maxWaitTimer
        interval: 6000
        onTriggered: skin.swapping = false
    }

    Connections {
        target: cover
        function onSettled() {
            // No art, or a failed load: nothing to wait for, so the disc
            // can leave now. A successful load waits instead for its own
            // fade, handled below by `onCoverReadyChanged`.
            if (skin.swapArmed && !cover.ready)
                skin.swapping = false;
        }
    }

    // Opaque only once the requested image has actually finished loading,
    // independent of `swapping`: the cover has to finish covering the disc
    // before the disc leaves, not move at the same time.
    readonly property bool coverReady: cover.ready
    property real coverOpacity: (skin.artUrl !== "" && coverReady) ? 1 : 0
    Behavior on coverOpacity { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    // Gives the fade above time to finish before the disc slides out.
    onCoverReadyChanged: {
        if (coverReady && swapArmed)
            slideOutTimer.restart();
    }

    Timer {
        id: slideOutTimer
        interval: 420
        onTriggered: skin.swapping = false
    }

    readonly property real discSize: size * 0.94

    // How much of the disc peeks out from the case's edge, as a fraction of
    // its diameter. Barely hinted at while docked, so pulling it out
    // actually reads as a change.
    readonly property real peekFraction: revealed ? 0.62 : 0.22

    // Whether the disc travels along the box's width (left/right) or its
    // height (top/bottom), and whether it travels in the increasing
    // (right/bottom) or decreasing (left/top) direction. Everything else in
    // this file is built from just these two flags.
    readonly property bool horizontal: peekSide === "left" || peekSide === "right"
    readonly property bool forward: peekSide === "right" || peekSide === "bottom"

    // Box: elongated along the peek axis to leave room for the disc, with
    // just a hair of margin across it.
    readonly property real longSide: Math.round(size * 1.62)
    readonly property real crossSide: Math.round(size * 1.02)

    implicitWidth: horizontal ? longSide : crossSide
    implicitHeight: horizontal ? crossSide : longSide

    readonly property real boxFactor: 1.62

    // The case sits at one end of the peek axis, centered on the cross
    // axis. `forward` means the disc pokes out past the case's far edge, so
    // the case itself sits at the near (0) end, and vice versa.
    readonly property real caseAlong: forward ? 0 : longSide - size
    readonly property real caseCross: (crossSide - size) / 2
    readonly property real caseX: horizontal ? caseAlong : caseCross
    readonly property real caseY: horizontal ? caseCross : caseAlong

    readonly property rect faceRect: Qt.rect(caseX, caseY, size, size)
    readonly property bool faceIsCircle: false

    SpinDriver {
        id: spin
        playing: skin.playing
        degreesPerSecond: skin.spinDegreesPerSecond
    }

    // ---------------------------------------------------------------
    // The disc. Sits behind the case, peeking out past whichever edge
    // `peekSide` names.
    // ---------------------------------------------------------------
    Item {
        id: discLayer

        width: skin.discSize
        height: skin.discSize

        // Centered on the cross axis, same centerline as the case. While
        // swapping the disc is also centered along the peek axis, so it
        // lines up with the cover's own position instead of the edge.
        readonly property real discCenteredCross: (skin.crossSide - skin.discSize) / 2
        readonly property real discCenteredAlong: skin.caseAlong + (skin.size - width) / 2

        // Along the peek axis when not swapping: at peekFraction 0 the disc
        // sits fully tucked behind the case (flush with whichever case edge
        // faces the peek direction); at 1 it's fully outside the case.
        readonly property real discRestingAlong: skin.forward
            ? (skin.caseAlong + skin.size) - width * (1 - skin.peekFraction)
            : skin.caseAlong - width * skin.peekFraction

        readonly property real discAlong: skin.swapping ? discCenteredAlong : discRestingAlong

        x: skin.horizontal ? discAlong : discCenteredCross
        y: skin.horizontal ? discCenteredCross : discAlong

        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }

        DiscFace {
            id: disc

            anchors.fill: parent
            size: skin.discSize
            rotation: spin.angle

            // The printed side, not the reflective one: it's the one that
            // carries the cover art, and that asymmetry is what actually
            // gives away that the disc is spinning. The concentric grooves
            // alone don't do it: a rotated circle is the same circle.
            artUrl: skin.artUrl
            labelSize: 940
            labelPlaceholder: "#aeb6c4"
            holeRadius: 62

            bodyColor: "#b9c1cf"
            rimColor: "#e9edf4"
            rimWidth: 3

            // Data tracks: many more of them, and much fainter than a
            // vinyl groove.
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

        // The rainbow sheen. Same conical highlight as the vinyl skin, with
        // different colors: on a CD the light splits into a spectrum
        // instead of just reflecting. Pushed noticeably brighter/more
        // opaque than the vinyl one, with a near-white hot core at its
        // peak: over a plain disc the old, subtler version read fine, but
        // it all but disappeared against a busy, colorful cover.
        Sheen {
            anchors.fill: parent
            holeRadius: skin.discSize * 62 / 1000
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

    // ---------------------------------------------------------------
    // The case. Sits on top of the disc, which is why the disc only shows
    // from the peek edge outward.
    // ---------------------------------------------------------------
    Item {
        id: jewelCase

        readonly property real corner: Math.round(skin.size * 0.025)
        readonly property real frame: Math.max(1, Math.round(skin.size * 0.012))
        // A real jewel case's spine is close to 6% of its width; at widget
        // size that reads as more aggressive than it does on a real case,
        // especially when it lands on a logo. Narrower than reality on
        // purpose, favoring "looks right small" over strict scale.
        readonly property real spineWidth: Math.max(3, Math.round(skin.size * 0.045))

        // The spine sits on the case's edge facing away from the disc: the
        // near (0) edge when the disc pokes forward, the far edge otherwise.
        readonly property bool spineAtNearEdge: skin.forward
        readonly property real spinePos: spineAtNearEdge ? 0 : size - spineWidth

        x: skin.caseX
        y: skin.caseY
        width: skin.size
        height: skin.size

        // The case's edge casting a shadow onto the disc. Fades with the
        // cover: it's the insert's shadow, not the frame's, so it has no
        // business being there once the insert is gone.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: jewelCase.corner
            color: Qt.rgba(0, 0, 0, 0.5)
            antialiasing: true
            opacity: skin.coverOpacity
        }

        // Body. Transparent fill: the frame border is the only part that's
        // actually plastic. A filled interior would block the disc from
        // showing through once the cover fades out.
        Rectangle {
            anchors.fill: parent
            radius: jewelCase.corner
            color: "transparent"
            border.width: jewelCase.frame
            border.color: "#767b85"
            antialiasing: true
        }

        // Cover art, with the plastic on top of it. That ordering is what
        // makes the cover read as something sitting inside the case, rather
        // than as the case itself.
        Rectangle {
            anchors.fill: parent
            anchors.margins: jewelCase.frame + 1
            radius: Math.max(1, jewelCase.corner - jewelCase.frame)
            color: "#20222a"
            antialiasing: true
            clip: true
            opacity: skin.coverOpacity

            CrossfadeImage {
                id: cover
                anchors.fill: parent
                source: skin.artUrl
            }

            // Diagonal glare, the tell that there's a sheet of plastic here.
            // A faint cool-to-warm fringe frames the white core: clear
            // plastic doesn't reflect perfectly white either, it splits a
            // little color at the edges of the highlight, same as the
            // disc's sheen but much weaker, since this is a thin cover
            // sheet, not the CD's diffracting data layer.
            Rectangle {
                width: parent.width * 2.4
                height: parent.height * 0.62
                anchors.centerIn: parent
                rotation: -26
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
                    GradientStop { position: 0.32; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
                    GradientStop { position: 0.40; color: Qt.rgba(0.55, 0.80, 1.00, 0.05) }
                    GradientStop { position: 0.47; color: Qt.rgba(0.90, 0.95, 1.00, 0.11) }
                    GradientStop { position: 0.50; color: Qt.rgba(1.00, 1.00, 1.00, 0.15) }
                    GradientStop { position: 0.53; color: Qt.rgba(1.00, 0.95, 0.92, 0.11) }
                    GradientStop { position: 0.60; color: Qt.rgba(1.00, 0.70, 0.55, 0.05) }
                    GradientStop { position: 0.68; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
                    GradientStop { position: 1.00; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
                }
            }

            // A second glare, narrower and shifted down: the plastic has two
            // faces, and each one throws back its own reflection. Same
            // fringe idea, kept even fainter since this one reads as a
            // secondary, weaker reflection.
            Rectangle {
                width: parent.width * 2.4
                height: parent.height * 0.22
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.58
                rotation: -26
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
                    GradientStop { position: 0.40; color: Qt.rgba(0.55, 0.80, 1.00, 0.03) }
                    GradientStop { position: 0.50; color: Qt.rgba(1.00, 1.00, 1.00, 0.07) }
                    GradientStop { position: 0.60; color: Qt.rgba(1.00, 0.70, 0.55, 0.03) }
                    GradientStop { position: 1.00; color: Qt.rgba(1.00, 1.00, 1.00, 0.00) }
                }
            }

            // The case isn't flat: it darkens toward the bottom.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.05) }
                    GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.00) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.26) }
                }
            }
        }

        // Spine: the hinge, with its ribbing. The single biggest tell that
        // this is a CD case and not just a loose cover. A vertical strip on
        // the left/right edge for a horizontal peek, a horizontal strip on
        // the top/bottom edge for a vertical one.
        Item {
            x: skin.horizontal ? jewelCase.spinePos : 0
            y: skin.horizontal ? 0 : jewelCase.spinePos
            width: skin.horizontal ? jewelCase.spineWidth : parent.width
            height: skin.horizontal ? parent.height : jewelCase.spineWidth
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "#0b0c0f"
            }

            // Ribbing.
            Repeater {
                model: 7

                Rectangle {
                    color: index % 2 === 0
                        ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.05)

                    width: skin.horizontal ? 1 : parent.width - jewelCase.corner
                    height: skin.horizontal ? parent.height - jewelCase.corner : 1
                    x: skin.horizontal
                        ? Math.round((index + 0.5) * jewelCase.spineWidth / 7)
                        : jewelCase.corner / 2
                    y: skin.horizontal
                        ? jewelCase.corner / 2
                        : Math.round((index + 0.5) * jewelCase.spineWidth / 7)
                }
            }

            // Crease.
            Rectangle {
                anchors.right: skin.horizontal && jewelCase.spineAtNearEdge ? parent.right : undefined
                anchors.left: skin.horizontal && !jewelCase.spineAtNearEdge ? parent.left : undefined
                anchors.bottom: !skin.horizontal && jewelCase.spineAtNearEdge ? parent.bottom : undefined
                anchors.top: !skin.horizontal && !jewelCase.spineAtNearEdge ? parent.top : undefined
                width: skin.horizontal ? 1 : parent.width
                height: skin.horizontal ? parent.height : 1
                color: Qt.rgba(0, 0, 0, 0.6)
            }
        }

        // Shadow easing the seam between the spine and the cover art onto
        // the cover itself. Without this the spine's edge read as an
        // abrupt, glitchy-looking cut through the artwork rather than a
        // believable piece of molded plastic sitting in front of it.
        Rectangle {
            readonly property real fade: Math.round(skin.size * 0.11)

            x: skin.horizontal
                ? (jewelCase.spineAtNearEdge ? jewelCase.spineWidth
                                              : jewelCase.width - jewelCase.spineWidth - fade)
                : 0
            y: skin.horizontal
                ? 0
                : (jewelCase.spineAtNearEdge ? jewelCase.spineWidth
                                              : jewelCase.height - jewelCase.spineWidth - fade)
            width: skin.horizontal ? fade : parent.width
            height: skin.horizontal ? parent.height : fade

            gradient: Gradient {
                orientation: skin.horizontal ? Gradient.Horizontal : Gradient.Vertical
                GradientStop {
                    position: 0.00
                    color: Qt.rgba(0, 0, 0, jewelCase.spineAtNearEdge ? 0.28 : 0.00)
                }
                GradientStop {
                    position: 1.00
                    color: Qt.rgba(0, 0, 0, jewelCase.spineAtNearEdge ? 0.00 : 0.28)
                }
            }
        }

        // Molded tabs, on the two edges away from the spine. On a real case
        // these are the stops that hold the tray in place, showing up as
        // small gray notches along the edge.
        Repeater {
            model: [[0.30, 0], [0.62, 0], [0.88, 0],
                    [0.30, 1], [0.62, 1], [0.88, 1]]

            Rectangle {
                readonly property real tabW: Math.round(skin.size * 0.11)
                readonly property real tabH: Math.round(skin.size * 0.035)

                width: skin.horizontal ? tabW : tabH
                height: skin.horizontal ? tabH : tabW
                radius: Math.min(width, height) / 2
                color: "#5f646d"
                antialiasing: true
                opacity: 0.85

                x: skin.horizontal
                    ? Math.round(modelData[0] * parent.width - tabW / 2)
                    : (modelData[1] ? parent.width - tabH - jewelCase.frame : jewelCase.frame)
                y: skin.horizontal
                    ? (modelData[1] ? parent.height - tabH - jewelCase.frame : jewelCase.frame)
                    : Math.round(modelData[0] * parent.height - tabW / 2)
            }
        }

        // Corners: on a real case the mold leaves a chamfer, and that edge
        // is the only part of it that actually shows. Same on all four
        // corners regardless of peek direction.
        Repeater {
            model: [[0, 0, 45], [1, 0, -45], [0, 1, -45], [1, 1, 45]]

            Rectangle {
                readonly property real inset: Math.round(skin.size * 0.055)

                width: Math.round(skin.size * 0.10)
                height: 1
                color: Qt.rgba(1, 1, 1, 0.16)
                rotation: modelData[2]
                transformOrigin: Item.Center
                x: (modelData[0] ? parent.width - inset : inset) - width / 2
                y: (modelData[1] ? parent.height - inset : inset) - height / 2
                antialiasing: true
            }
        }
    }
}
