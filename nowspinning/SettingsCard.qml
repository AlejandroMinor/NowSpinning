// The settings, behind the gear: a card beside the widget (flipped to the
// other side when there's no room), in three sections: Skin, a live preview
// of each with what is playing; Size; and the current skin's options. Built
// from the window's `settingsOptions`; picks go back through `picked`.
// Stays open until the gear or its ✕ close it.
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: card

    property var host            // the widget's window
    property rect face           // the face, in the window's coordinates
    property bool open: false
    property var options: []     // [{ id, items: [{ key, label, on }] }]
    property var skins: ({})     // skin name -> Component
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property color accent: "white"
    signal picked(string section, string key)
    signal closeRequested()

    readonly property var headings: ({ skin: "Skin", size: "Size", toggle: "Options" })
    readonly property int tile: 60
    readonly property int columns: 5

    anchor.window: host
    anchor.rect.x: face.x + face.width + 10
    anchor.rect.y: face.y + face.height / 2
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Right
    anchor.gravity: Edges.Right
    anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideY

    visible: open
    color: "transparent"
    implicitWidth: columns * tile + (columns - 1) * 6 + 28
    implicitHeight: content.implicitHeight + 28

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.82)
        border { width: 1; color: Qt.rgba(1, 1, 1, 0.08) }
    }

    component Heading: Text {
        color: Qt.rgba(1, 1, 1, 0.45)
        font { pixelSize: 11; weight: Font.DemiBold }
    }

    component Chip: Item {
        id: chip
        property var item
        property string group
        width: chipText.implicitWidth + 20
        height: 24
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.item.on
                ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.85)
                : Qt.rgba(1, 1, 1, chipHover.hovered ? 0.18 : 0.09)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.item.label
            color: chip.item.on ? "#101215" : Qt.rgba(1, 1, 1, 0.85)
            font { pixelSize: 11; weight: Font.DemiBold }
        }
        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: card.picked(chip.group, chip.item.key) }
    }

    ColumnLayout {
        id: content
        x: 14
        y: 14
        width: card.implicitWidth - 28
        spacing: 8

        Repeater {
            model: card.options

            ColumnLayout {
                id: section
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    visible: section.index > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    implicitHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Heading { text: card.headings[section.modelData.id] ?? section.modelData.id }
                    Item { Layout.fillWidth: true }
                    // Closes the card; only on the first section's row.
                    Text {
                        visible: section.index === 0
                        text: "\u2715"
                        color: Qt.rgba(1, 1, 1, closeHover.hovered ? 0.9 : 0.5)
                        font.pixelSize: 12
                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: card.closeRequested() }
                    }
                }

                // Skin: a tile per skin, drawing it live.
                Grid {
                    visible: section.modelData.id === "skin"
                    columns: card.columns
                    spacing: 6
                    Repeater {
                        model: section.modelData.id === "skin" ? section.modelData.items : []
                        delegate: Rectangle {
                            id: skinTile
                            required property var modelData
                            width: card.tile
                            height: card.tile + 14
                            radius: 10
                            color: modelData.on
                                ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.3)
                                : Qt.rgba(1, 1, 1, tileHover.hovered ? 0.12 : 0.05)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Item {
                                id: box
                                x: 6; y: 6
                                width: card.tile - 12
                                height: card.tile - 12
                                clip: true
                                Loader {
                                    id: preview
                                    active: card.visible
                                    sourceComponent: card.skins[skinTile.modelData.key] ?? null
                                    readonly property real fit: item
                                        ? Math.min(box.width / item.implicitWidth, box.height / item.implicitHeight) : 1
                                    transformOrigin: Item.TopLeft
                                    scale: fit
                                    x: item ? (box.width - item.implicitWidth * fit) / 2 : 0
                                    y: item ? (box.height - item.implicitHeight * fit) / 2 : 0
                                    // Shrunk through a mipmapped layer, or fine detail comes out jagged.
                                    layer.enabled: item !== null
                                    layer.mipmap: true
                                    layer.smooth: true
                                    onLoaded: {
                                        item.size = 170;
                                        item.artUrl = Qt.binding(() => card.artUrl);
                                        item.playing = Qt.binding(() => card.playing);
                                        if (item.title !== undefined)
                                            item.title = Qt.binding(() => card.title);
                                        if (item.trackChangeToken !== undefined)
                                            item.trackChangeToken += 1;
                                    }
                                }
                            }
                            Text {
                                anchors { bottom: parent.bottom; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
                                text: skinTile.modelData.label
                                color: Qt.rgba(1, 1, 1, skinTile.modelData.on ? 1 : 0.7)
                                font { pixelSize: 10; weight: skinTile.modelData.on ? Font.DemiBold : Font.Normal }
                            }
                            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: card.picked("skin", skinTile.modelData.key) }
                        }
                    }
                }

                // Size and options: chips.
                Flow {
                    visible: section.modelData.id !== "skin"
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: section.modelData.id !== "skin" ? section.modelData.items : []
                        delegate: Chip {
                            required property var modelData
                            item: modelData
                            group: section.modelData.id
                        }
                    }
                }
            }
        }
    }
}
