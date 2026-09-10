// The track card, shown in place of the disc's usual face on request. It
// exists because the face itself has no room for it: the title gets cut
// off there, and there's no space for the album or the time.
//
// Has no background of its own; the caller supplies that. The text splits
// above and below center, leaving room for a disc's center hole and rings
// to be drawn on top of it.
import QtQuick

Item {
    id: root

    property int size: 170
    property var source        // MprisSource

    // Gap left free in the middle for the center hole.
    readonly property real gap: Math.round(size * 0.10)

    Column {
        width: parent.width * 0.60
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: root.gap / 2
        spacing: Math.round(root.size * 0.012)

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.source ? root.source.title : ""
            color: "white"
            font.pixelSize: Math.max(9, Math.round(root.size * 0.060))
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.source ? root.source.artist : ""
            color: Qt.rgba(1, 1, 1, 0.72)
            font.pixelSize: Math.max(8, Math.round(root.size * 0.051))
            elide: Text.ElideRight
        }
    }

    Column {
        width: parent.width * 0.60
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: root.gap / 2
        spacing: Math.round(root.size * 0.012)

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.source ? root.source.album : ""
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: Math.max(7, Math.round(root.size * 0.045))
            elide: Text.ElideRight
            visible: text.length > 0
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.58)
            font.pixelSize: Math.max(8, Math.round(root.size * 0.049))
            font.family: "monospace"
            visible: text.length > 0
            text: {
                if (!root.source || root.source.duration <= 0)
                    return "";
                return root.source.formatClock(root.source.position)
                    + " / " + root.source.formatClock(root.source.duration);
            }
        }
    }
}
