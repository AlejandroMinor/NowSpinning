// Skin: the track as a gig poster pasted on a wall.
//
// The cover art under a LIVE band, the artist in big condensed capitals,
// the title, tonight's date and doors, printed on cheap paper that the
// paste has wrinkled, each poster its own way. A new track gets pasted
// over the last, rolled on from the top. Paused, a POSTPONED strip goes
// across its corner.
//
// Under the pointer its bottom corner peels off the wall, more the closer
// the pointer gets to it, showing the poster underneath.
//
// The band, the artist and the date are printed in the cover's accent
// (the window's tint), or in red when there isn't one. The back, for the
// track info, is a black poster with nothing on it.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist` and `accent`.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property string artist: ""
    property color accent: "white"
    property bool blankLabel: false
    property bool lightTilt: true     // the corner peeling under the pointer

    readonly property bool supportsFullArt: false
    property bool artFull: false

    implicitWidth: Math.round(size * 0.86)
    implicitHeight: Math.round(implicitWidth * 1.38)

    readonly property real boxFactor: implicitHeight / size
    readonly property rect faceRect: Qt.rect(0, 0, width, height)
    readonly property bool faceIsCircle: false

    // Laid out on a 200 x 276 grid, scaled to the size.
    readonly property real u: implicitWidth / 200

    // The ink: the accent, or red when the accent is plain white.
    readonly property color ink: accent.hslSaturation < 0.15 ? "#d6312b" : accent

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: skin.faceRect
    }

    // How far the corner has come off, 0..1: more the nearer the pointer.
    readonly property real reach: {
        if (!light.following || blankLabel)
            return 0;
        const d = Math.hypot(width - light.pointer.x, height - light.pointer.y);
        return Math.max(0.35, Math.min(1, 1.25 - d / (width * 0.9)));
    }
    property real curl: reach
    Behavior on curl { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    readonly property real fold: curl * 62 * u

    // What the poster underneath shows: the last track's, kept once a
    // track has settled (the title and the cover can change at different
    // moments, so it waits a beat).
    property var settled: ({ art: "", title: "", artist: "", ink: "#d6312b" })
    property var under: ({ art: "", title: "", artist: "", ink: "#d6312b" })
    Timer {
        id: settling
        interval: 1500
        onTriggered: skin.settled = { art: skin.artUrl, title: skin.title, artist: skin.artist, ink: skin.ink }
    }
    onTitleChanged: settling.restart()
    onArtistChanged: settling.restart()
    onArtUrlChanged: {
        settling.restart();
        if (blankLabel)
            return;
        if (settled.art && settled.art !== artUrl)
            under = settled;
        pasting.restart();
    }

    // A new poster rolls on from the top.
    property real pasted: 1
    NumberAnimation {
        id: pasting
        target: skin
        property: "pasted"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.InOutQuad
    }

    function hash(s) {
        let n = 3;
        for (let i = 0; i < s.length; i++)
            n = (n * 31 + s.charCodeAt(i)) % 2147483647;
        return n;
    }
    readonly property string date: {
        const d = new Date();
        return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][d.getDay()] + " " + d.getDate() + " "
            + ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][d.getMonth()];
    }

    component Poster: Item {
        id: poster
        property string art
        property string title
        property string artist
        property color ink: "#d6312b"
        property bool blank: false
        width: skin.width
        height: skin.height

        Rectangle {
            anchors.fill: parent
            color: poster.blank ? "#1d1c1a" : "#efe9dc"
        }
        Item {
            anchors.fill: parent
            visible: !poster.blank

            Rectangle {
                width: parent.width
                height: 22 * skin.u
                color: poster.ink
                Text {
                    anchors.centerIn: parent
                    text: "LIVE · ONE NIGHT ONLY"
                    color: "white"
                    font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(9 * skin.u)); weight: Font.Black; letterSpacing: 1.5 * skin.u }
                }
            }
            Rectangle {
                x: 12 * skin.u
                y: 28 * skin.u
                width: 176 * skin.u
                height: 128 * skin.u
                color: "#2a2826"
                clip: true
                Image {
                    anchors.fill: parent
                    source: poster.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize { width: 400; height: 400 }
                    asynchronous: true
                    // Cheap print: harder, a little flatter.
                    layer.enabled: true
                    layer.effect: MultiEffect { contrast: 0.3; saturation: -0.2; brightness: 0.03 }
                }
            }
            Text {
                x: 10 * skin.u
                y: 158 * skin.u
                width: 180 * skin.u
                height: 44 * skin.u
                text: poster.artist.toUpperCase()
                fontSizeMode: Text.Fit
                minimumPixelSize: 6
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                color: poster.ink
                font { family: "sans-serif"; pixelSize: Math.round(44 * skin.u); weight: Font.Black; letterSpacing: -0.4 * skin.u }
            }
            Text {
                x: 12 * skin.u
                y: 204 * skin.u
                width: 176 * skin.u
                text: "“" + poster.title + "”"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: "#1d1c1a"
                font { family: "serif"; pixelSize: Math.max(6, Math.round(15 * skin.u)); italic: true }
            }
            Rectangle {
                x: 40 * skin.u
                y: 229 * skin.u
                width: 120 * skin.u
                height: Math.max(1, 1.2 * skin.u)
                color: "#1d1c1a"
            }
            Text {
                x: 12 * skin.u
                y: 236 * skin.u
                width: 176 * skin.u
                text: skin.date + " · DOORS 8PM"
                horizontalAlignment: Text.AlignHCenter
                color: poster.ink
                font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(11 * skin.u)); weight: Font.Black; letterSpacing: 0.8 * skin.u }
            }
            Text {
                x: 12 * skin.u
                y: 254 * skin.u
                width: 176 * skin.u
                text: "NOW PLAYING · ALL AGES · NO REFUNDS"
                horizontalAlignment: Text.AlignHCenter
                color: Qt.rgba(0.11, 0.11, 0.1, 0.7)
                font { family: "sans-serif"; pixelSize: Math.max(4, Math.round(7 * skin.u)); weight: Font.Bold; letterSpacing: 0.6 * skin.u }
            }
        }

        // The paste's wrinkles, bubbles and stains: lit on one side, dark
        // on the other, each poster its own.
        Canvas {
            anchors.fill: parent
            property string seed: poster.art + poster.title
            onSeedChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                let s = skin.hash(seed) || 1;
                const rand = () => (s = (s * 16807) % 2147483647) / 2147483647;
                const W = width, H = height;
                ctx.lineCap = "round";
                // Softer on the black poster, where light shows more.
                const k = poster.blank ? 0.35 : 1;
                for (let i = 0; i < 4; i++) {
                    // A crease: mostly up and down, the way paste runs, as a
                    // soft fold lit on one side and shaded on the other.
                    const x = rand() * W, y = rand() * H * 0.8;
                    const a = Math.PI / 2 + (rand() - 0.5) * 0.7;
                    const len = (0.25 + rand() * 0.5) * H;
                    const dx = Math.cos(a) * len, dy = Math.sin(a) * len;
                    const bend = (rand() - 0.5) * W * 0.1;
                    const lw = skin.u * (2 + rand() * 3);
                    for (const side of [{ c: "rgba(255, 255, 255, " + 0.13 * k + ")", o: -lw * 0.5, w: lw },
                                        { c: "rgba(60, 45, 25, " + 0.08 * k + ")", o: lw * 0.5, w: lw },
                                        { c: "rgba(60, 45, 25, " + 0.12 * k + ")", o: 0, w: Math.max(0.5, skin.u * 0.4) }]) {
                        ctx.strokeStyle = side.c;
                        ctx.lineWidth = side.w;
                        ctx.beginPath();
                        ctx.moveTo(x + side.o, y);
                        ctx.quadraticCurveTo(x + dx / 2 + bend + side.o, y + dy / 2, x + dx + side.o, y + dy);
                        ctx.stroke();
                    }
                }
                for (let i = 0; i < 4; i++) {
                    // An air bubble under the paper.
                    const x = rand() * W, y = rand() * H, r = (6 + rand() * 10) * skin.u;
                    const g = ctx.createRadialGradient(x - r * 0.3, y - r * 0.3, 0, x, y, r);
                    g.addColorStop(0, "rgba(255, 255, 255, " + 0.22 * k + ")");
                    g.addColorStop(0.75, "rgba(255, 255, 255, 0)");
                    g.addColorStop(1, "rgba(30, 20, 10, " + 0.08 * k + ")");
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.ellipse(x - r, y - r * 0.8, 2 * r, 1.6 * r);
                    ctx.fill();
                }
                for (let i = 0; i < 3; i++) {
                    // Paste soaked through, near an edge.
                    const x = rand() < 0.5 ? rand() * W * 0.2 : W - rand() * W * 0.2, y = rand() * H;
                    const r = (14 + rand() * 20) * skin.u;
                    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
                    g.addColorStop(0, "rgba(120, 95, 50, 0.12)");
                    g.addColorStop(1, "rgba(120, 95, 50, 0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(x - r, y - r, 2 * r, 2 * r);
                }
            }
        }
    }

    // The one underneath, the last track's.
    Poster {
        visible: skin.under.art !== "" && !skin.blankLabel
        art: skin.under.art
        title: skin.under.title
        artist: skin.under.artist
        ink: skin.under.ink
    }

    // The new one, rolled on from the top, its corner cut where it peels.
    Item {
        id: front
        width: skin.width
        height: skin.height * skin.pasted
        clip: true

        Item {
            id: sheet
            width: skin.width
            height: skin.height
            layer.enabled: skin.fold > 0.5
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: outline
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.2
            }
            Poster {
                art: skin.artUrl
                title: skin.title
                artist: skin.artist
                ink: skin.ink
                blank: skin.blankLabel
            }
        }
    }
    // The roller's edge, while it pastes.
    Rectangle {
        visible: skin.pasted > 0 && skin.pasted < 1
        y: skin.height * skin.pasted - height / 2
        width: skin.width
        height: 6 * skin.u
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.3) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
        }
    }

    // The poster's outline less the peeled corner: the mask.
    Item {
        id: outline
        width: skin.width
        height: skin.height
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: outline.width; y: 0 }
                PathLine { x: outline.width; y: outline.height - skin.fold }
                PathLine { x: outline.width - skin.fold; y: outline.height }
                PathLine { x: 0; y: outline.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // The corner folded back: the paper's back, paste on it.
    Shape {
        visible: skin.fold > 0.5
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.rgba(0, 0, 0, 0.15)
            strokeWidth: 0.5
            fillGradient: LinearGradient {
                x1: skin.width - skin.fold; y1: skin.height - skin.fold
                x2: skin.width - skin.fold / 2; y2: skin.height - skin.fold / 2
                GradientStop { position: 0; color: "#d9d1bf" }
                GradientStop { position: 1; color: "#f3eee3" }
            }
            startX: skin.width - skin.fold; startY: skin.height
            PathLine { x: skin.width; y: skin.height - skin.fold }
            PathLine { x: skin.width - skin.fold; y: skin.height - skin.fold }
            PathLine { x: skin.width - skin.fold; y: skin.height }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.45
            shadowBlur: 0.35
            shadowHorizontalOffset: -2 * skin.u
            shadowVerticalOffset: -2 * skin.u
        }
    }

    // Paused: POSTPONED across the top corner.
    Item {
        anchors.fill: parent
        clip: true
        opacity: !skin.playing && !skin.blankLabel ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Rectangle {
            width: skin.width * 0.95
            height: 20 * skin.u
            x: skin.width * 0.42
            y: 30 * skin.u
            rotation: 38
            color: "#ffd23f"
            border { width: Math.max(1, skin.u); color: "#1d1c1a" }
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -skin.width * 0.08
                text: "POSTPONED"
                color: "#1d1c1a"
                font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(11 * skin.u)); weight: Font.Black; letterSpacing: 1.2 * skin.u }
            }
        }
    }
}
