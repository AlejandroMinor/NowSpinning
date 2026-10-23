// The lyrics, under the widget: the current line, and around it the ones
// before and after, faded.
//
// Its own layer surface, not part of the widget's window: that one is the
// skin's exact size, and growing it would move every skin's hit area and
// docking around. This one takes no input at all, so clicks go straight
// through to whatever's behind it. It follows the widget as it's dragged,
// and goes above it instead when there's no room below.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: lyricsWindow

    property var lyrics             // Lyrics.qml
    property rect widget            // the widget's skin, on screen
    property int lines: 3           // 1 or 3
    property real scale: 1          // follows the widget's size
    property bool shown: false

    readonly property int lineHeight: Math.round(18 * scale)
    readonly property int gap: Math.round(8 * scale)
    readonly property int boxWidth: Math.round(Math.max(260, widget.width * 1.6))
    readonly property int boxHeight: lineHeight * (lines === 1 ? 2 : 4) + 12

    readonly property int screenH: screen ? screen.height : 1080
    readonly property bool below: widget.y + widget.height + gap + boxHeight <= screenH

    anchors { top: true; left: true }
    margins {
        left: Math.round(widget.x + widget.width / 2 - boxWidth / 2)
        top: below ? Math.round(widget.y + widget.height + gap)
                   : Math.round(widget.y - gap - boxHeight)
    }
    implicitWidth: boxWidth
    implicitHeight: boxHeight

    visible: shown && lyrics && lyrics.status === "synced" && lyrics.index >= 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nowspinning-lyrics"
    mask: Region {}

    component Line: Text {
        width: lyricsWindow.boxWidth
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        color: "white"
    }

    Column {
        id: column
        anchors.centerIn: parent
        spacing: Math.round(2 * lyricsWindow.scale)

        // Readable over any wallpaper: a soft dark halo behind the text.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.9
            shadowBlur: 0.6
            shadowVerticalOffset: 1
        }

        Line {
            visible: lyricsWindow.lines > 1
            text: lyricsWindow.lyrics ? lyricsWindow.lyrics.previous : ""
            opacity: 0.45
            font.pixelSize: Math.round(12 * lyricsWindow.scale)
        }

        Line {
            id: currentLine
            text: lyricsWindow.lyrics ? lyricsWindow.lyrics.current : ""
            font.pixelSize: Math.round(15 * lyricsWindow.scale)
            font.weight: Font.DemiBold

            // A quick fade-in on every new line.
            onTextChanged: appear.restart()
            NumberAnimation on opacity {
                id: appear
                from: 0.2; to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Line {
            visible: lyricsWindow.lines > 1
            text: lyricsWindow.lyrics ? lyricsWindow.lyrics.next : ""
            opacity: 0.45
            font.pixelSize: Math.round(12 * lyricsWindow.scale)
        }
    }
}
