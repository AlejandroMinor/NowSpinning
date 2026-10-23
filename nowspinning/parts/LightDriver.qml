// Where the light hits a flat skin, -1..1 across `area` on each axis.
//
// Drifts side to side on its own while playing; follows the pointer while
// it's over the skin. Skins read lightX/lightY and decide what that moves:
// a tilt, a glint, a foil, or nothing at all.
//
// Fill the skin with it: `area` is in the skin's coordinates. The pointer
// is measured as if the skin weren't turned, so a skin can tilt itself
// whole without the tilt moving the pointer and the pointer the tilt. Smoothed here, so nothing jumps when
// the pointer comes in or leaves and every reader moves together.
import QtQuick

Item {
    id: driver

    property bool playing: false
    property bool motion: true    // the light drifting on its own
    property bool follow: true    // the light following the pointer
    property rect area: Qt.rect(0, 0, width, height)

    readonly property bool following: follow && hover.hovered
    readonly property point pointer: {
        const p = hover.point.scenePosition;
        const host = driver.parent;
        if (!host || !host.parent)
            return hover.point.position;
        const q = host.parent.mapFromItem(null, p.x, p.y);
        return Qt.point(q.x - host.x, q.y - host.y);
    }
    property real lightX: following
        ? Math.max(-1, Math.min(1, (pointer.x - area.x) / area.width * 2 - 1)) : drift
    property real lightY: following
        ? Math.max(-1, Math.min(1, (pointer.y - area.y) / area.height * 2 - 1)) : 0
    // Where the light is, as a direction from the middle: degrees clockwise
    // from straight up, the way ConicalGradient counts them.
    readonly property real heading: Math.atan2(lightY, lightX) * 180 / Math.PI + 90
    // The same, from some other point of the skin: a disc that isn't in
    // the middle of it. Rests at 0 while not following.
    function headingFrom(cx, cy) {
        if (!following)
            return 0;
        return Math.atan2(pointer.y - cy, pointer.x - cx) * 180 / Math.PI + 90;
    }
    Behavior on lightX { SmoothedAnimation { duration: 180; velocity: -1 } }
    Behavior on lightY { SmoothedAnimation { duration: 180; velocity: -1 } }

    property real drift: 0
    SequentialAnimation on drift {
        running: driver.playing && driver.motion && !driver.following
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 3200; easing.type: Easing.InOutSine }
        NumberAnimation { to: -1; duration: 3200; easing.type: Easing.InOutSine }
    }

    HoverHandler { id: hover }
}
