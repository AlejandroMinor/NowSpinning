// Windows' take on ../CursorProbe.qml: there the cursor's place on the
// desktop is simply known, and asked for directly, so the widget is dragged
// 1:1 here too. Picked over the Linux one by nowspinning.exe; Quickshell
// never reads this folder.
import QtQuick
import NowSpinning.Host

Item {
    id: probe

    readonly property bool available: true
    signal moved(real cursorX, real cursorY)

    function ask() {
        const p = Cursor.position();
        probe.moved(p.x, p.y);
    }
}
