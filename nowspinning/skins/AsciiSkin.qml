// Skin: the cover as ASCII art: each cell's brightness picks a character
// from RAMP, in the cell's colour (or white).
//
// Ported from HyprFlow's media panel skins. The back, for the track info,
// is the blank terminal.
//
// Sways while playing and turns toward the pointer, like the foil card.
//
// See VinylSkin.qml for the skin contract.
import QtQuick
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property bool blankLabel: false
    property int columns: 32
    property bool colored: true
    property bool lightMotion: true  // swaying on its own
    property bool lightTilt: true    // turning toward the pointer

    readonly property string ramp: " .:-=+*#%@"
    readonly property real cellWidth: size / columns
    readonly property real cellHeight: cellWidth / 0.6  // monospace glyphs are tall
    readonly property int rows: Math.floor(size / cellHeight)
    property var cells: []  // { ch, color }, row by row

    implicitWidth: size
    implicitHeight: size

    readonly property bool supportsFullArt: false
    property bool artFull: false
    readonly property real boxFactor: 1
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    Rectangle {
        anchors.fill: parent
        radius: skin.size * 0.06
        color: "black"
    }

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: skin.lightMotion
        follow: skin.lightTilt
        area: skin.faceRect
    }

    transform: [
        Tilt { target: skin; amount: light.lightX; degrees: 9 },
        Tilt { target: skin; amount: light.lightY; degrees: 9; vertical: true }
    ]

    // Draws the cover at one pixel per cell and reads the pixels back.
    Canvas {
        id: sampler
        width: skin.columns
        height: skin.rows
        opacity: 0
        onImageLoaded: requestPaint()
        onPaint: {
            if (!skin.artUrl || !isImageLoaded(skin.artUrl))
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(skin.artUrl, 0, 0, width, height);
            const data = ctx.getImageData(0, 0, width, height).data;
            const out = [];
            for (let i = 0; i < width * height; i++) {
                const r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2];
                // Lifted: on black, dark covers would barely show.
                const light = Math.pow((0.299 * r + 0.587 * g + 0.114 * b) / 255, 0.6);
                const lift = c => Math.min(1, 0.25 + c / 255 * 1.1);
                out.push({ ch: skin.ramp[Math.min(skin.ramp.length - 1, Math.floor(light * skin.ramp.length))],
                           color: Qt.rgba(lift(r), lift(g), lift(b), 1) });
            }
            skin.cells = out;
            painter.requestPaint();
        }
    }

    // The cover the sampler holds: a Canvas keeps every image it loads until
    // told to drop it, so only the current one is kept.
    property string held: ""
    function load() {
        if (held !== "" && held !== artUrl)
            sampler.unloadImage(held);
        held = artUrl;
        if (!artUrl)
            return;
        if (sampler.isImageLoaded(artUrl))
            sampler.requestPaint();
        else
            sampler.loadImage(artUrl);
    }
    onArtUrlChanged: load()
    onColumnsChanged: load()

    Canvas {
        id: painter
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (skin.blankLabel || skin.cells.length !== skin.columns * skin.rows)
                return;
            ctx.font = Math.round(skin.cellHeight) + "px 'JetBrainsMono Nerd Font', monospace";
            ctx.textBaseline = "top";
            const top = (height - skin.rows * skin.cellHeight) / 2;
            for (let r = 0; r < skin.rows; r++) {
                for (let c = 0; c < skin.columns; c++) {
                    const cell = skin.cells[r * skin.columns + c];
                    if (cell.ch === " ")
                        continue;
                    ctx.fillStyle = skin.colored ? cell.color : "#e6e6e6";
                    ctx.fillText(cell.ch, c * skin.cellWidth, top + r * skin.cellHeight);
                }
            }
        }
    }
    onColoredChanged: painter.requestPaint()
    onBlankLabelChanged: painter.requestPaint()
}
