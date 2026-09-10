// The controls overlay, revealed on hover. Knows nothing about the skin: it
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
            text: root.source ? root.source.artist : ""
            color: Qt.rgba(1, 1, 1, 0.62)
            font.pixelSize: Math.max(8, Math.round(root.size * 0.056))
        }

        Item { width: 1; height: Math.round(root.size * 0.03) }

        Row {
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

            ProgressRing {
                anchors.fill: parent
                linear: true
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
                color: Qt.rgba(1, 1, 1, 0.55)
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
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
            }
        }
    }
}
