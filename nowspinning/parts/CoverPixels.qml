// The cover's colours on a small grid, for a skin that redraws the cover its
// own way (in dots, dithered, in glass, in lines). Cut square from the
// middle of the cover (a wide video thumbnail too), drawn at twice the
// grid and averaged down, so a busy cover doesn't come out as noise.
//
// Read once per cover: `pixels` holds r, g, b (0..255) per cell, row by
// row, and `sampled` fires each time it's new. An empty `source` empties
// it. Put it anywhere in the skin; it's never seen.
import QtQuick

Canvas {
    id: root

    property string source: ""
    property int columns: 64
    property int rows: columns
    property var pixels: []
    signal sampled()

    readonly property int over: 2
    width: columns * over
    height: rows * over
    // Never shown, but a Canvas that isn't visible never paints.
    opacity: 0

    // What the pixels were last read from. The Canvas repaints on its own
    // now and then (in a layer, under a transform), and each repaint would
    // read the cover again and set the skin redrawing it all: once is
    // enough.
    property string sampledFrom: ""

    // Every cover this Canvas asked for. A Canvas keeps each image it loads
    // until told to drop it: a cover per track, at full size, for as long
    // as the widget runs. But one still on its way must never be dropped:
    // that cancels its download half-sent, and Qt's connection doesn't
    // always recover, so later covers stop arriving. Old ones go only once
    // they've loaded, whenever a load finishes.
    property var asked: []
    function tidy() {
        const keep = [];
        for (const url of asked) {
            if (url === source || !isImageLoaded(url))
                keep.push(url);
            else
                unloadImage(url);
        }
        asked = keep;
    }

    function load() {
        sampledFrom = "";
        if (!source) {
            pixels = [];
            sampled();
        } else {
            // One already loaded (by this Canvas, or cached from another)
            // may never say so.
            if (asked.indexOf(source) < 0)
                asked = asked.concat([source]);
            if (!isImageLoaded(source))
                loadImage(source);
            if (isImageLoaded(source))
                requestPaint();
        }
        tidy();
    }
    onSourceChanged: load()
    onColumnsChanged: load()
    onRowsChanged: load()
    Component.onCompleted: load()
    onImageLoaded: {
        tidy();
        requestPaint();
    }

    onPaint: {
        // A cover that loaded after the source moved on isn't ours.
        if (!source || !isImageLoaded(source))
            return;
        const key = source + "@" + columns + "x" + rows;
        if (key === sampledFrom)
            return;
        const ctx = getContext("2d");
        const natural = ctx.createImageData(source);
        let sw = natural.width, sh = natural.height;
        if (sw <= 0 || sh <= 0)
            return;
        const aspect = columns / rows;
        if (sw / sh > aspect)
            sw = sh * aspect;
        else
            sh = sw / aspect;
        ctx.clearRect(0, 0, width, height);
        ctx.drawImage(source, (natural.width - sw) / 2, (natural.height - sh) / 2, sw, sh,
                      0, 0, width, height);
        const data = ctx.getImageData(0, 0, width, height).data;
        const out = new Array(columns * rows * 3);
        const n = over * over;
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < columns; c++) {
                let red = 0, green = 0, blue = 0;
                for (let y = 0; y < over; y++) {
                    let i = ((r * over + y) * width + c * over) * 4;
                    for (let x = 0; x < over; x++, i += 4) {
                        red += data[i];
                        green += data[i + 1];
                        blue += data[i + 2];
                    }
                }
                const o = (r * columns + c) * 3;
                out[o] = red / n;
                out[o + 1] = green / n;
                out[o + 2] = blue / n;
            }
        }
        sampledFrom = key;
        pixels = out;
        sampled();
    }
}
