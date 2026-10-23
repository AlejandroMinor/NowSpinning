// An accent color picked out of the cover art, for the progress indicator
// and anything else that wants to follow the album instead of plain white.
//
// Quickshell's own ColorQuantizer only reads local files, and players hand
// over cover art as a remote URL (Spotify's are https), so this samples the
// pixels itself: the cover gets drawn onto a tiny canvas and read back.
//
// The most common hue isn't necessarily the right pick: a photo that's
// mostly beige sky with a red jacket in it should come out red, not beige.
// So hues are weighted by how saturated they are, and whatever wins gets
// its lightness pinned high enough to read against the dark overlay and a
// dark desktop. Covers with no real color in them (black and white, gray
// on gray) stay white rather than getting a muddy tint invented for them.
import QtQuick

Item {
    id: root

    property string source: ""
    property bool enabled: true

    // White until a cover has been read, and whenever there's no usable
    // color in it.
    readonly property color accent: target

    // Whether `accent` is an actual color from the cover, as opposed to the
    // white fallback. Flips immediately; `accent` itself fades.
    property bool tinted: false

    property color target: "white"
    Behavior on target { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }

    // Painting needs a real, rendered item, but there's nothing to see.
    width: sample
    height: sample
    opacity: 0

    readonly property int sample: 32

    onSourceChanged: pick()
    onEnabledChanged: pick()

    function pick() {
        if (!enabled || source === "") {
            target = "white";
            tinted = false;
            return;
        }
        if (canvas.isImageLoaded(source))
            canvas.requestPaint();
        else
            canvas.loadImage(source);
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        property string loaded: ""

        onImageLoaded: {
            // Only the newest cover matters, and each loaded image stays in
            // memory until it's explicitly dropped.
            if (loaded !== "" && loaded !== root.source)
                unloadImage(loaded);
            loaded = root.source;
            requestPaint();
        }

        onPaint: {
            if (!root.enabled || !isImageLoaded(root.source))
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, root.sample, root.sample);
            ctx.drawImage(root.source, 0, 0, root.sample, root.sample);
            const picked = root.accentOf(ctx.getImageData(0, 0, root.sample, root.sample).data);
            root.tinted = picked !== null;
            root.target = picked ?? "white";
        }
    }

    function accentOf(data) {
        // 12 hue buckets, 30 degrees each.
        const weight = new Array(12).fill(0);
        const sums = [];
        for (let i = 0; i < 12; i++)
            sums.push([0, 0, 0]);

        let pixels = 0;
        let colorful = 0;
        for (let i = 0; i < data.length; i += 4) {
            const c = Qt.rgba(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255, 1);
            pixels++;
            const s = c.hsvSaturation;
            const v = c.hsvValue;
            // Near-black and washed-out pixels carry no real hue.
            if (v < 0.18 || s < 0.22 || c.hsvHue < 0)
                continue;
            const w = s * s * v;
            const b = Math.min(11, Math.floor(c.hsvHue * 12));
            weight[b] += w;
            sums[b][0] += data[i] * w;
            sums[b][1] += data[i + 1] * w;
            sums[b][2] += data[i + 2] * w;
            colorful++;
        }

        // Less than about one pixel in twelve with real color in it: a
        // grayscale cover with a speck of something, not a colored one.
        if (colorful < pixels / 12)
            return null;

        let best = 0;
        for (let i = 1; i < 12; i++)
            if (weight[i] > weight[best])
                best = i;

        const w = weight[best];
        const picked = Qt.rgba(sums[best][0] / w / 255, sums[best][1] / w / 255,
                               sums[best][2] / w / 255, 1);
        return Qt.hsla(picked.hslHue,
                       Math.max(0.40, Math.min(0.85, picked.hslSaturation)),
                       0.70, 1);
    }
}
