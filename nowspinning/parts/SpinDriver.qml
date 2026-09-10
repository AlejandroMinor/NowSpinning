// A disc's spin, with inertia.
//
// Speed chases its target with a delay, like a real platter picking up
// revolutions. That delay, not the animation itself, is what makes the
// spin feel smooth: without it, the disc would snap to full speed and stop
// dead instantly.
//
// Keeps ticking after playback pauses, until the disc actually comes to a
// stop. Otherwise there would be no spin-down to feel.
import QtQuick

QtObject {
    id: driver

    property bool playing: false

    // Degrees per second at cruising speed. A real 33 1/3 RPM would be 200,
    // but at widget size that reads as a fan blade. 9 is the slow,
    // decorative spin: 40 seconds per revolution.
    property real degreesPerSecond: 9

    // How fast the speed reaches its cruising target. Higher = snappier.
    property real responsiveness: 2.2

    readonly property real angle: privateState.angle
    readonly property bool moving: playing || privateState.speed > 0.05

    readonly property QtObject privateState: QtObject {
        property real angle: 0
        property real speed: 0
    }

    readonly property Timer ticker: Timer {
        interval: 16
        repeat: true
        running: driver.moving

        property double last: 0
        onRunningChanged: last = Date.now()

        onTriggered: {
            const now = Date.now();
            const dt = Math.min(0.05, (now - last) / 1000);
            last = now;

            const target = driver.playing ? driver.degreesPerSecond : 0;
            const s = driver.privateState;
            s.speed += (target - s.speed) * Math.min(1, dt * driver.responsiveness);
            s.angle = (s.angle + s.speed * dt) % 360;
        }
    }
}
