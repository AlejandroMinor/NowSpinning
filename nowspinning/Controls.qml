// The controls overlay, revealed by a click. Knows nothing about the skin: it
// just draws itself on top of a `size` circle (or rounded rect) and that's it.
import QtQuick

Item {
    id: root

    property int size: 170
    property var source        // MprisSource
    property bool shown: false

    // Not every skin is round: the overlay's shape matches the face's.
    property bool circular: true
    property real cornerRadius: Math.round(size * 0.06)

    // Time bar drawn in here, as an alternative to the ring around the disc.
    property bool showProgress: false

    // Color for the time bar and the volume fill; see ArtAccent.qml.
    property color accent: "white"
    property real accentAlpha: 0.55

    property bool showTransport: true

    // Whether the settings card (SettingsCard.qml, beside the widget) is
    // open; the gear switches it, the window closes it.
    property bool settingsOpen: false

    // Replaces the artist line while set: the time a click would jump to,
    // while the pointer is over the ring outside this overlay.
    property string hint: ""

    // Where on the bar a point falls, 0..1, or -1 if it isn't on the bar or
    // the bar can't seek right now. `x`/`y` are in `from`'s coordinates.
    // The bar is thin, so a band above and below it counts too.
    function barFraction(from, x, y) {
        if (!shown || settingsOpen || !showProgress || !source || !source.canSeek)
            return -1;
        const p = bar.mapFromItem(from, x, y);
        if (p.x < 0 || p.x > bar.width)
            return -1;
        return bar.fractionAt(p.x, p.y, Math.max(6, root.size * 0.06));
    }

    readonly property real barPreview: barHover.hovered
        ? barFraction(barHover.parent, barHover.point.position.x, barHover.point.position.y)
        : -1

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

    // Volume only shows up while it's being changed. Shown permanently, it
    // got confused for the time bar, which is what people expect to see there.
    property bool volumeVisible: false

    Connections {
        target: root.source
        function onVolumeChanged() {
            root.volumeVisible = true;
            volumeHide.restart();
        }
    }

    Timer {
        id: volumeHide
        interval: 1400
        onTriggered: root.volumeVisible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: root.circular ? width / 2 : root.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.72)
        antialiasing: true
    }

    Column {
        anchors.centerIn: parent
        width: parent.width * 0.74
        spacing: Math.round(root.size * 0.018)
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.source ? root.source.title : ""
            color: "white"
            font.pixelSize: Math.max(9, Math.round(root.size * 0.065))
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.barPreview >= 0 && root.source
                ? root.source.formatClock(root.barPreview * root.source.duration)
                : (root.hint || (root.source ? root.source.artist : ""))
            color: Qt.rgba(1, 1, 1, 0.62)
            font.pixelSize: Math.max(8, Math.round(root.size * 0.056))
        }

        Item { width: 1; height: Math.round(root.size * 0.03) }

        Row {
            // A skin with its own transport keys (the walkman) doesn't
            // need a second set drawn over it.
            visible: root.showTransport
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.size * 0.045)

            IconButton {
                width: Math.round(root.size * 0.17); height: width
                kind: "prev"
                active: root.source ? root.source.canPrev : false
                onActivated: root.source.previous()
            }

            IconButton {
                width: Math.round(root.size * 0.17); height: width
                kind: root.source && root.source.playing ? "pause" : "play"
                active: root.source ? root.source.canToggle : false
                onActivated: root.source.toggle()
            }

            IconButton {
                width: Math.round(root.size * 0.17); height: width
                kind: "next"
                active: root.source ? root.source.canNext : false
                onActivated: root.source.next()
            }
        }

        Item { width: 1; height: Math.round(root.size * 0.025) }

        // Both bars keep their slot even when hidden: if they appeared and
        // disappeared, the whole column would jump.
        Item {
            width: parent.width
            height: Math.max(6, Math.round(root.size * 0.055))

            // Hover over a taller strip than the bar itself: at widget size
            // the bar is a few pixels tall, too thin to aim at.
            Item {
                anchors.centerIn: parent
                width: parent.width
                height: Math.max(parent.height, Math.round(root.size * 0.14))
                HoverHandler { id: barHover }
            }

            ProgressRing {
                id: bar
                anchors.fill: parent
                linear: true
                preview: root.barPreview
                visible: root.showProgress && root.source && root.source.duration > 0
                progress: root.source ? root.source.progress : 0
                waves: 7
                amplitude: root.source && root.source.playing
                    ? Math.max(1.5, root.size * 0.014) : 0
                Behavior on amplitude {
                    NumberAnimation { duration: 550; easing.type: Easing.InOutQuad }
                }
                flowing: root.shown && root.source && root.source.playing
                thickness: Math.max(1.5, root.size * 0.011)
                headRadius: Math.max(2, root.size * 0.018)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.accentAlpha)
            }

            // Volume, layered on top, only while it's being adjusted.
            Item {
                anchors.centerIn: parent
                width: parent.width
                height: Math.max(2, Math.round(root.size * 0.018))

                opacity: root.volumeVisible && root.source && root.source.hasVolume ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.75)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                Rectangle {
                    height: parent.height
                    width: parent.width * (root.source ? root.source.volume : 0)
                    radius: height / 2
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85)
                }
            }
        }
    }

    // Whether a point lands on the gear, so the window's own tap (which
    // flips the widget) leaves it alone. `x`/`y` are in `from`'s coordinates.
    function onSettings(from, x, y) {
        if (!shown)
            return false;
        for (const item of [gear, closeButton]) {
            const p = item.mapFromItem(from, x, y);
            if (p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height)
                return true;
        }
        return false;
    }

    // Close, top right: quits the widget. Two clicks, so a stray one can't:
    // the first arms it (it turns red), the second, within two seconds,
    // closes. Left alone, it disarms.
    //
    // On a round face it sits on the diagonal, inside the curve; on a
    // rectangular one, in the corner.
    property bool closeArmed: false
    onShownChanged: if (!shown) closeArmed = false
    Timer { id: disarm; interval: 2000; onTriggered: root.closeArmed = false }

    Item {
        id: closeButton
        readonly property real d: Math.max(14, Math.round(root.size * 0.11))
        readonly property real inset: root.circular
            ? root.width / 2 - (root.width / 2 - d * 0.8) * Math.SQRT1_2
            : Math.round(root.size * 0.05) + d / 2
        x: root.width - inset - d / 2
        y: inset - d / 2
        width: d
        height: d

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.closeArmed ? "#d9443a"
                : Qt.rgba(1, 1, 1, closeHover.hovered ? 0.18 : 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        IconButton {
            anchors.centerIn: parent
            width: parent.width * 0.62; height: width
            kind: "close"
            enabled: false   // the whole circle takes the click
        }

        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (root.closeArmed) {
                    Qt.quit();
                    return;
                }
                root.closeArmed = true;
                disarm.restart();
            }
        }
    }

    // Gear, near the bottom edge: opens the settings card, and closes it.
    Item {
        id: gear
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.size * (root.circular ? 0.07 : 0.05))
        width: Math.round(root.size * 0.17)
        height: Math.round(root.size * 0.11)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.settingsOpen
                ? Qt.rgba(1, 1, 1, 0.26)
                : Qt.rgba(1, 1, 1, gearHover.hovered ? 0.16 : 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        IconButton {
            anchors.centerIn: parent
            width: Math.max(10, Math.round(root.size * 0.09)); height: width
            kind: "gear"
            enabled: false   // the whole pill takes the click
        }

        HoverHandler { id: gearHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.settingsOpen = !root.settingsOpen }
    }
}
