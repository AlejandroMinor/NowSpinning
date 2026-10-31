// The settings, behind the gear: a card beside the widget (flipped to the
// other side when there's no room), in two tabs. Skin: the skins in groups
// (Physical, Flat, Cyber...), one group at a time, each a live preview with
// what is playing, and the current skin's own options under its name. Widget: what's the same for every skin (size, layer, tint, shadow,
// audio, lyrics), from the sections marked `block: "widget"`. A section can
// name its own heading (`title`); one without a heading carries on the one
// above it, with no line between. Built
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
    property var options: []     // [{ id, title?, items: [{ key, label, on }] }]
    property var skins: ({})     // skin name -> Component
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property color accent: "white"
    signal picked(string section, string key)
    signal closeRequested()

    // The skin tiles go unnamed: their tab already says it.
    readonly property var headings: ({ skin: "", size: "Size", toggle: "Options" })
    function heading(s) { return s.title ?? headings[s.id] ?? ""; }
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

    // The widget resizes under it (a new skin, a new size, the shadow's
    // room coming or going): re-anchor once the new geometry has settled,
    // or the card stays where the old face was.
    function reanchor() {
        if (visible)
            Qt.callLater(() => anchor.updateAnchor());
    }
    onFaceChanged: reanchor()
    // And when the card itself changes height (a tab, a group, the
    // previews loading in): its middle has to stay level with the widget.
    onImplicitHeightChanged: reanchor()
    onVisibleChanged: reanchor()
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

    // One section: its heading (and the line above it), then the skin
    // tiles or the chips.
    component Section: ColumnLayout {
        id: section
        required property var modelData
        property bool lined: true   // the line above the heading
        Layout.fillWidth: true
        spacing: 6

        readonly property string title: card.heading(modelData)

        Rectangle {
            visible: section.lined && section.title !== ""
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }
        Heading {
            visible: section.title !== ""
            text: section.title
        }

            // Skin: the groups, then a tile per skin of the shown one,
            // drawing it live.
            Flow {
                visible: section.modelData.id === "skin" && (section.modelData.groups ?? []).length > 0
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: section.modelData.id === "skin" ? (section.modelData.groups ?? []) : []
                    delegate: Item {
                        id: groupChip
                        required property var modelData
                        readonly property bool current: card.shownGroup(section.modelData) === modelData.key
                        width: groupText.implicitWidth + 16
                        height: 22
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: groupChip.current ? Qt.rgba(1, 1, 1, 0.14)
                                : Qt.rgba(1, 1, 1, groupHover.hovered ? 0.08 : 0)
                            border { width: 1; color: Qt.rgba(1, 1, 1, groupChip.current ? 0 : 0.1) }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Text {
                            id: groupText
                            anchors.centerIn: parent
                            text: groupChip.modelData.label
                            color: Qt.rgba(1, 1, 1, groupChip.current ? 0.95 : 0.6)
                            font { pixelSize: 11; weight: Font.DemiBold }
                        }
                        HoverHandler { id: groupHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: card.skinGroup = groupChip.modelData.key }
                    }
                }
            }
            Grid {
                id: skinGrid
                visible: section.modelData.id === "skin"
                columns: card.columns
                spacing: 6

                // As tall as the biggest group, whichever is shown, so the
                // card keeps its size when going from one to another.
                readonly property int most: {
                    const counts = {};
                    for (const i of section.modelData.items ?? [])
                        counts[i.group] = (counts[i.group] ?? 0) + 1;
                    return Math.max(1, ...Object.values(counts));
                }
                readonly property int rows: Math.ceil(most / card.columns)
                Layout.minimumHeight: rows * (card.tile + 14) + (rows - 1) * spacing
                Layout.alignment: Qt.AlignTop

                // A new group fades in, sliding from the side it's on.
                readonly property int groupIndex: (section.modelData.groups ?? [])
                    .findIndex(g => g.key === card.shownGroup(section.modelData))
                property int lastIndex: -1
                property int direction: 1
                onGroupIndexChanged: {
                    if (lastIndex >= 0 && groupIndex !== lastIndex) {
                        direction = groupIndex > lastIndex ? 1 : -1;
                        entering.restart();
                    }
                    lastIndex = groupIndex;
                }
                Component.onCompleted: lastIndex = groupIndex
                transform: Translate { id: slide }
                ParallelAnimation {
                    id: entering
                    NumberAnimation { target: skinGrid; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutQuad }
                    NumberAnimation { target: slide; property: "x"; from: 18 * skinGrid.direction; to: 0; duration: 260; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: section.modelData.id === "skin"
                        ? section.modelData.items.filter(i => !i.group || i.group === card.shownGroup(section.modelData))
                        : []
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

    component CloseButton: Text {
        text: "\u2715"
        color: Qt.rgba(1, 1, 1, closeHover.hovered ? 0.9 : 0.5)
        font.pixelSize: 12
        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: card.closeRequested() }
    }

    // The skin's sections, and the widget's (`block: "widget"`).
    readonly property var skinSections: options.filter(s => s.block !== "widget")
    readonly property var widgetSections: options.filter(s => s.block === "widget")

    property string tab: "skin"

    // Which group of skins the Skin tab shows: picked with its chips, or,
    // until one is, the current skin's. Reopening goes back to that.
    property string skinGroup: ""
    onOpenChanged: if (open) skinGroup = ""
    function shownGroup(section) {
        if (skinGroup !== "")
            return skinGroup;
        const current = section.items.find(i => i.on);
        return current ? current.group : (section.groups?.[0]?.key ?? "");
    }

    ColumnLayout {
        id: content
        x: 14
        y: 14
        width: card.implicitWidth - 28
        spacing: 8

        // Tabs, with the close button beside them.
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: [{ key: "skin", label: "Skin" }, { key: "widget", label: "Widget" }]
                Item {
                    id: tabButton
                    required property var modelData
                    readonly property bool current: card.tab === modelData.key
                    implicitWidth: tabText.implicitWidth + 24
                    implicitHeight: 26
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: tabButton.current ? Qt.rgba(1, 1, 1, 0.14)
                            : Qt.rgba(1, 1, 1, tabHover.hovered ? 0.08 : 0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: tabButton.modelData.label
                        color: Qt.rgba(1, 1, 1, tabButton.current ? 0.95 : 0.55)
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }
                    HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: card.tab = tabButton.modelData.key }
                }
            }
            Item { Layout.fillWidth: true }
            CloseButton {}
        }

        Repeater {
            model: card.tab === "widget" ? card.widgetSections : card.skinSections
            Section {
                required property int index
                lined: index > 0
            }
        }
    }
}
