// Skin: the track as a poker hand, the cover on the joker.
//
// A fanned hand of 5 cards (or 3), the joker up front in the middle with
// the cover as its face. The others make a hand that the joker completes as
// the wild card: a pair, three of a kind, a straight, a flush, a full
// house... up to five of a kind. Each track deals its own hand, always the
// same one for the same track, the rarer hands coming up less often. The
// joker's face carries the title above the cover and the hand's name below.
//
// On each new track the hand is gathered into a pile and dealt again.
// Paused, the other cards turn face down and only the joker stays up.
// Under the pointer the hand turns toward it, fans out a little wider and
// the joker rises.
//
// The card backs take the cover's colour. Rectangular face (the joker), so
// the window swaps the ring for the bar on its own. The back, for the
// track info, is the same hand face down.
//
// See VinylSkin.qml for the skin contract. On top of the usual subset, this
// one reads the optional `title`, `artist`, `accent` and
// `trackChangeToken`, and its own `cardsHand` (5 or 3).
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../parts"

Item {
    id: skin

    property int size: 170
    property string artUrl: ""
    property bool playing: false
    property string title: ""
    property string artist: ""
    property color accent: "white"
    property int trackChangeToken: 0
    property bool blankLabel: false
    property bool lightTilt: true     // the hand turning toward the pointer
    property int cardsHand: 5         // cards in the hand, joker included: 5 or 3

    readonly property bool supportsFullArt: false
    property bool artFull: false

    readonly property int count: cardsHand === 3 ? 3 : 5
    readonly property int middle: (count - 1) / 2

    // One card, and how the hand fans out: each card turned about a point
    // below the hand, like held in a fist.
    readonly property real cw: Math.round(size * 0.62)
    readonly property real ch: Math.round(cw * 1.4)
    readonly property real pivot: ch * 1.1
    readonly property real step: count === 3 ? 12 : 9
    readonly property real spreadMax: 1.15
    readonly property real liftMax: ch * 0.05
    readonly property real margin: size * 0.05

    // How far the hand reaches from the middle card's centre, fanned out
    // as wide as it gets under the pointer, so the box never changes size
    // while hovering.
    readonly property var reach: {
        let side = 0, down = 0;
        const up = ch / 2 * 1.04 + liftMax;
        for (let i = 0; i < count; i++) {
            const a = (i - middle) * step * spreadMax * Math.PI / 180;
            const sx = Math.abs(Math.sin(a)), c = Math.cos(a);
            side = Math.max(side, pivot * sx + cw / 2 * c + ch / 2 * sx);
            down = Math.max(down, pivot * (1 - c) + cw / 2 * sx + ch / 2 * c);
        }
        return { side: side, up: up, down: down };
    }

    implicitWidth: Math.round(2 * reach.side + 2 * margin)
    implicitHeight: Math.round(reach.up + reach.down + 2 * margin)

    // The middle card's centre.
    readonly property real cx: implicitWidth / 2
    readonly property real cy: margin + reach.up

    readonly property real boxFactor: implicitWidth / size
    readonly property rect faceRect: Qt.rect(cx - cw / 2, cy - ch / 2, cw, ch)
    readonly property bool faceIsCircle: false
    // It casts its own, card by card.
    readonly property bool ownShadow: true

    readonly property color red: "#c41f2b"
    readonly property color black: "#16161a"
    readonly property color paper: "#fbf9f4"

    // The backs, in the cover's colour; a cover with no real colour in it
    // gets the classic red.
    readonly property color backColor: accent.hslSaturation < 0.22
        ? "#a3212b"
        : Qt.hsla(accent.hslHue, Math.min(0.8, accent.hslSaturation), 0.36, 1)

    // ---------------------------------------------------------------
    // The hand
    // ---------------------------------------------------------------

    readonly property var suits: ["♠", "♥", "♦", "♣"]
    readonly property var ranks: ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

    // The track the cards on the table were dealt for. Moves on halfway
    // through the deal, while the cards are gathered.
    property string handKey: ""
    Component.onCompleted: handKey = title + "\u0001" + artist

    readonly property var hand: deal(handKey, count)

    // Each hand, how often it comes up, and how to deal it. `n` is the
    // cards besides the joker. Every hand is dealt so the joker makes it
    // and nothing better: no accidental flush under a straight, no pair
    // that could also run.
    readonly property var handsOf5: [
        { name: "Five of a Kind", weight: 2, kind: "five" },
        { name: "Royal Flush", weight: 2, kind: "royal" },
        { name: "Straight Flush", weight: 5, kind: "straightflush" },
        { name: "Four of a Kind", weight: 10, kind: "four" },
        { name: "Full House", weight: 12, kind: "full" },
        { name: "Flush", weight: 12, kind: "flush" },
        { name: "Straight", weight: 14, kind: "straight" },
        { name: "Three of a Kind", weight: 22, kind: "three" },
        { name: "Pair", weight: 21, kind: "pair" }
    ]
    // Three-card poker: a three of a kind beats a straight there, and a
    // straight beats a flush.
    readonly property var handsOf3: [
        { name: "Straight Flush", weight: 6, kind: "straightflush" },
        { name: "Three of a Kind", weight: 14, kind: "three" },
        { name: "Straight", weight: 22, kind: "straight" },
        { name: "Flush", weight: 24, kind: "flush" },
        { name: "Pair", weight: 34, kind: "pair" }
    ]

    function deal(key, cards) {
        // A seed from the track, then a small PRNG off it (mulberry32).
        let h = 2166136261;
        for (let i = 0; i < key.length; i++)
            h = Math.imul(h ^ key.charCodeAt(i), 16777619);
        let seed = h >>> 0;
        const rnd = () => {
            seed = (seed + 0x6D2B79F5) >>> 0;
            let t = seed;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
        const pick = n => Math.floor(rnd() * n);
        const shuffled = list => {
            const a = list.slice();
            for (let i = a.length - 1; i > 0; i--) {
                const j = pick(i + 1);
                [a[i], a[j]] = [a[j], a[i]];
            }
            return a;
        };
        // n distinct ranks out of 13.
        const distinctRanks = n => shuffled([...Array(13).keys()]).slice(0, n);
        // Whether these distinct ranks, plus the joker, could make a
        // straight: all of them inside some five (or three) in a row, the
        // ace high or low.
        const couldRun = (rs, span) => {
            const fits = list => Math.max(...list) - Math.min(...list) < span
                && new Set(list).size === list.length;
            return fits(rs) || (rs.includes(12) && fits(rs.map(r => r === 12 ? -1 : r)));
        };
        // Suits for cards that mustn't all share one.
        const mixedSuits = n => {
            for (;;) {
                const s = [...Array(n)].map(() => pick(4));
                if (new Set(s).size > 1)
                    return s;
            }
        };

        const n = cards - 1;
        const table = cards === 3 ? handsOf3 : handsOf5;
        const span = cards === 3 ? 3 : 5;
        let roll = rnd() * table.reduce((sum, t) => sum + t.weight, 0);
        let type = table[table.length - 1];
        for (const t of table) {
            roll -= t.weight;
            if (roll < 0) {
                type = t;
                break;
            }
        }

        let rs = [], ss = [], suited = -1;
        switch (type.kind) {
        case "five": {
            const r = pick(13);
            rs = [r, r, r, r];
            ss = [0, 1, 2, 3];
            break;
        }
        case "royal":
        case "straightflush":
        case "straight": {
            // A run with a gap inside it, never at its ends: the joker has
            // to go in the gap, so it can't stretch the run into a better
            // one (10 J Q K plus the joker as an ace).
            const top = type.kind === "royal" ? 12 : 12 - (type.kind === "straightflush" ? 1 : 0);
            const low = type.kind === "royal" ? 12 - (span - 1) : pick(top - (span - 1) + 1);
            const run = [...Array(span).keys()].map(i => low + i);
            run.splice(1 + pick(span - 2), 1);
            rs = run;
            if (type.kind === "straight")
                ss = mixedSuits(n);
            else {
                suited = pick(4);
                ss = rs.map(() => suited);
            }
            break;
        }
        case "four": {
            const [r, k] = distinctRanks(2);
            const s = shuffled([0, 1, 2, 3]);
            rs = [r, r, r, k];
            ss = [s[0], s[1], s[2], pick(4)];
            break;
        }
        case "full": {
            const [a, b] = distinctRanks(2);
            const sa = shuffled([0, 1, 2, 3]), sb = shuffled([0, 1, 2, 3]);
            rs = [a, a, b, b];
            ss = [sa[0], sa[1], sb[0], sb[1]];
            break;
        }
        case "flush": {
            do
                rs = distinctRanks(n);
            while (couldRun(rs, span));
            suited = pick(4);
            ss = rs.map(() => suited);
            break;
        }
        case "three": {
            if (cards === 3) {
                const r = pick(13);
                const s = shuffled([0, 1, 2, 3]);
                rs = [r, r];
                ss = [s[0], s[1]];
            } else {
                const [r, a, b] = distinctRanks(3);
                const s = shuffled([0, 1, 2, 3]);
                rs = [r, r, a, b];
                ss = [s[0], s[1], pick(4), pick(4)];
            }
            break;
        }
        default: {   // pair
            do
                rs = distinctRanks(n);
            while (couldRun(rs, span));
            ss = mixedSuits(n);
        }
        }

        // Held in order, the joker in the middle.
        const held = rs.map((r, i) => ({ rank: r, suit: ss[i], joker: false }))
            .sort((a, b) => a.rank - b.rank || a.suit - b.suit);
        held.splice((cards - 1) / 2, 0, { rank: -1, suit: -1, joker: true });
        return {
            cards: held,
            name: type.name.toUpperCase() + (suited >= 0 ? "  " + suits[suited] : ""),
            suitedRed: suited === 1 || suited === 2
        };
    }

    // ---------------------------------------------------------------
    // Motion
    // ---------------------------------------------------------------

    LightDriver {
        id: light
        anchors.fill: parent
        playing: skin.playing
        motion: false
        follow: skin.lightTilt
        area: Qt.rect(skin.margin, skin.margin, skin.implicitWidth - 2 * skin.margin,
                      skin.implicitHeight - 2 * skin.margin)
    }

    // The hand fanning out a little wider and the joker rising, 0..1.
    property real spread: light.following ? 1 : 0
    Behavior on spread { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    // How far the hand is dealt, 0 (gathered in a pile) to 1 (fanned out).
    property real dealt: 1
    onTrackChangeTokenChanged: {
        if (blankLabel)
            handKey = title + "\u0001" + artist;
        else {
            dealOut.stop();
            dealing.restart();
        }
    }
    SequentialAnimation {
        id: dealing
        NumberAnimation { target: skin; property: "dealt"; to: 0; duration: 200; easing.type: Easing.InCubic }
        // The artist can land a beat after the title; read both here.
        ScriptAction { script: { skin.handKey = skin.title + "\u0001" + skin.artist; skin.gathered = true; skin.dealWhenReady(); } }
    }
    NumberAnimation {
        id: dealOut
        target: skin; property: "dealt"; to: 1; duration: 760; easing.type: Easing.OutCubic
    }

    // The cover the joker shows. A new one comes off the network (Spotify
    // sends a URL), so it's fetched here first, out of sight, and the hand
    // stays gathered until it's in: the joker comes back with its new face
    // instead of a blank one that fills in a second later. Same URL and
    // size as the joker's own image, so that one then reads it from cache.
    property string shownArt: ""
    property bool gathered: false
    Image {
        id: nextArt
        visible: false
        source: skin.blankLabel ? "" : skin.artUrl
        sourceSize { width: 400; height: 400 }
        asynchronous: true
        // Outside a deal (the first cover, one that lands after its
        // title), it goes straight onto the joker.
        onStatusChanged: {
            if (skin.gathered)
                skin.dealWhenReady();
            else if (status === Image.Ready)
                skin.shownArt = source.toString();
        }
        onSourceChanged: if (!skin.gathered && source.toString() === "") skin.shownArt = ""
    }
    function dealWhenReady(force) {
        if (!gathered)
            return;
        if (nextArt.status === Image.Loading && !force) {
            if (!artWait.running)
                artWait.start();
            return;
        }
        artWait.stop();
        if (nextArt.status === Image.Ready || nextArt.source.toString() === "")
            shownArt = nextArt.source.toString();
        gathered = false;
        dealOut.restart();
    }
    // A slow or dead link doesn't hold the hand forever.
    Timer {
        id: artWait
        interval: 2500
        onTriggered: skin.dealWhenReady(true)
    }

    // ---------------------------------------------------------------
    // The cards
    // ---------------------------------------------------------------

    Item {
        id: table
        anchors.fill: parent

        transform: [
            Tilt { target: table; amount: light.lightX; degrees: 7 },
            Tilt { target: table; amount: light.lightY; degrees: 7; vertical: true }
        ]

        Repeater {
            model: skin.count

            Item {
                id: card

                required property int index
                readonly property var info: skin.hand.cards[index] ?? { rank: 0, suit: 0, joker: false }
                readonly property bool joker: index === skin.middle
                readonly property bool isRed: info.suit === 1 || info.suit === 2
                readonly property color ink: isRed ? skin.red : skin.black

                // Dealt from the joker outward, the joker first.
                readonly property real order: Math.abs(index - skin.middle)
                readonly property real t: Math.max(0, Math.min(1,
                    (skin.dealt * (1 + 0.18 * skin.middle) - 0.18 * order)))

                x: skin.cx - skin.cw / 2
                y: skin.cy - skin.ch / 2 + (1 - t) * skin.ch * 0.06
                   - (joker ? skin.spread * skin.liftMax : 0)
                width: skin.cw
                height: skin.ch
                z: joker ? 100 : index
                scale: joker ? 1.04 : 1

                transform: Rotation {
                    origin.x: skin.cw / 2
                    origin.y: skin.ch / 2 + skin.pivot
                    angle: (card.index - skin.middle) * skin.step * (1 + (skin.spreadMax - 1) * skin.spread) * card.t
                }

                // Face down, 0 (up) to 1 (down): the others while paused,
                // all of them on the widget's back.
                property real flip: skin.blankLabel || (!skin.playing && !joker) ? 1 : 0
                Behavior on flip {
                    SequentialAnimation {
                        PauseAnimation { duration: 70 * card.order }
                        NumberAnimation { duration: 300; easing.type: Easing.InOutSine }
                    }
                }

                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowOpacity: card.joker ? 0.5 : 0.35
                    shadowBlur: 0.4
                    shadowHorizontalOffset: -skin.cw * 0.015
                    shadowVerticalOffset: skin.cw * 0.02
                }

                Item {
                    id: turning
                    anchors.fill: parent
                    transform: Scale {
                        origin.x: skin.cw / 2
                        xScale: Math.max(0.02, Math.abs(Math.cos(card.flip * Math.PI)))
                    }

                    // The card itself.
                    Rectangle {
                        anchors.fill: parent
                        radius: skin.cw * 0.07
                        color: skin.paper
                        border { width: Math.max(1, skin.cw * 0.008); color: "#c9c3b6" }
                    }

                    Loader {
                        anchors.fill: parent
                        active: card.flip < 0.5
                        sourceComponent: card.joker ? jokerFace : (card.info.rank >= 9 && card.info.rank <= 11 ? courtFace
                                         : card.info.rank === 12 ? aceFace : pipFace)
                    }
                    Loader {
                        anchors.fill: parent
                        active: card.flip >= 0.5
                        sourceComponent: backFace
                    }

                    // The rank and suit in two corners, for every card but
                    // the joker.
                    Repeater {
                        model: card.joker || card.flip >= 0.5 ? 0 : 2
                        Column {
                            required property int index
                            x: index === 0 ? skin.cw * 0.06 : skin.cw * 0.94 - width
                            y: index === 0 ? skin.cw * 0.06 : skin.ch - skin.cw * 0.06 - height
                            rotation: index === 0 ? 0 : 180
                            spacing: -skin.cw * 0.03
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: skin.ranks[card.info.rank]
                                color: card.ink
                                font { family: "serif"; pixelSize: Math.max(6, Math.round(skin.cw * 0.16)); weight: Font.Bold; letterSpacing: card.info.rank === 8 ? -skin.cw * 0.015 : 0 }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: skin.suits[card.info.suit]
                                color: card.ink
                                font { family: "serif"; pixelSize: Math.max(6, Math.round(skin.cw * 0.13)) }
                            }
                        }
                    }

                    // Number cards: their pips, laid out the usual way.
                    Component {
                        id: pipFace
                        Item {
                            readonly property var layouts: ({
                                2: [[.5, 0], [.5, 1]],
                                3: [[.5, 0], [.5, .5], [.5, 1]],
                                4: [[0, 0], [1, 0], [0, 1], [1, 1]],
                                5: [[0, 0], [1, 0], [.5, .5], [0, 1], [1, 1]],
                                6: [[0, 0], [1, 0], [0, .5], [1, .5], [0, 1], [1, 1]],
                                7: [[0, 0], [1, 0], [.5, .25], [0, .5], [1, .5], [0, 1], [1, 1]],
                                8: [[0, 0], [1, 0], [.5, .25], [0, .5], [1, .5], [.5, .75], [0, 1], [1, 1]],
                                9: [[0, 0], [1, 0], [0, 1 / 3], [1, 1 / 3], [.5, .5], [0, 2 / 3], [1, 2 / 3], [0, 1], [1, 1]],
                                10: [[0, 0], [1, 0], [.5, 1 / 6], [0, 1 / 3], [1, 1 / 3], [0, 2 / 3], [1, 2 / 3], [.5, 5 / 6], [0, 1], [1, 1]]
                            })
                            Repeater {
                                model: parent.layouts[card.info.rank + 2] ?? []
                                Text {
                                    required property var modelData
                                    readonly property real px: skin.cw * (0.3 + 0.4 * modelData[0])
                                    readonly property real py: skin.ch * (0.2 + 0.6 * modelData[1])
                                    x: px - width / 2
                                    y: py - height / 2
                                    rotation: modelData[1] > 0.5 ? 180 : 0
                                    text: skin.suits[card.info.suit]
                                    color: card.ink
                                    font { family: "serif"; pixelSize: Math.max(6, Math.round(skin.cw * 0.2)) }
                                }
                            }
                        }
                    }

                    // The ace: one big pip.
                    Component {
                        id: aceFace
                        Item {
                            Text {
                                anchors.centerIn: parent
                                text: skin.suits[card.info.suit]
                                color: card.ink
                                font { family: "serif"; pixelSize: Math.max(10, Math.round(skin.cw * 0.5)) }
                            }
                        }
                    }

                    // J, Q, K: a framed panel with the letter, the suit above
                    // and below.
                    Component {
                        id: courtFace
                        Item {
                            Rectangle {
                                x: skin.cw * 0.22
                                y: skin.ch * 0.13
                                width: skin.cw * 0.56
                                height: skin.ch * 0.74
                                radius: skin.cw * 0.03
                                color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.06)
                                border { width: Math.max(1, skin.cw * 0.012); color: card.ink }

                                Text {
                                    anchors.centerIn: parent
                                    text: skin.ranks[card.info.rank]
                                    color: card.ink
                                    font { family: "serif"; pixelSize: Math.max(10, Math.round(skin.cw * 0.42)); weight: Font.Bold }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: parent.height * 0.06
                                    text: skin.suits[card.info.suit]
                                    color: card.ink
                                    font { family: "serif"; pixelSize: Math.max(6, Math.round(skin.cw * 0.14)) }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: parent.height * 0.94 - height
                                    rotation: 180
                                    text: skin.suits[card.info.suit]
                                    color: card.ink
                                    font { family: "serif"; pixelSize: Math.max(6, Math.round(skin.cw * 0.14)) }
                                }
                            }
                        }
                    }

                    // The joker: the cover, JOKER down two corners, the title
                    // above and the hand below.
                    Component {
                        id: jokerFace
                        Item {
                            readonly property real art: skin.cw * 0.72
                            readonly property real artY: (skin.ch - art) / 2

                            Repeater {
                                model: 2
                                Column {
                                    required property int index
                                    x: index === 0 ? skin.cw * 0.045 : skin.cw * 0.955 - width
                                    y: index === 0 ? skin.cw * 0.06 : skin.ch - skin.cw * 0.06 - height
                                    rotation: index === 0 ? 0 : 180
                                    spacing: -skin.cw * 0.025
                                    Repeater {
                                        model: ["J", "O", "K", "E", "R", "★"]
                                        Text {
                                            required property string modelData
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData
                                            color: skin.backColor
                                            font { family: "serif"; pixelSize: Math.max(5, Math.round(skin.cw * 0.085)); weight: Font.Black }
                                        }
                                    }
                                }
                            }

                            Text {
                                x: (skin.cw - width) / 2
                                width: parent.art
                                y: parent.artY - height - skin.cw * 0.035
                                horizontalAlignment: Text.AlignHCenter
                                text: skin.title
                                elide: Text.ElideRight
                                color: skin.black
                                font { family: "serif"; pixelSize: Math.max(5, Math.round(skin.cw * 0.078)); italic: true }
                            }

                            ClippingRectangle {
                                x: (skin.cw - width) / 2
                                y: parent.artY
                                width: parent.art
                                height: parent.art
                                radius: skin.cw * 0.03
                                color: "#d8d2c5"
                                border { width: Math.max(1, skin.cw * 0.01); color: skin.backColor }
                                CrossfadeImage {
                                    anchors.fill: parent
                                    source: skin.shownArt
                                    sourceWidth: 400
                                    sourceHeight: 400
                                }
                            }

                            Text {
                                x: (skin.cw - width) / 2
                                width: parent.art
                                y: parent.artY + parent.art + skin.cw * 0.04
                                horizontalAlignment: Text.AlignHCenter
                                text: skin.hand.name
                                elide: Text.ElideRight
                                color: skin.hand.suitedRed ? skin.red : skin.black
                                font { family: "sans-serif"; pixelSize: Math.max(5, Math.round(skin.cw * 0.068)); weight: Font.Black; letterSpacing: skin.cw * 0.008 }
                            }
                        }
                    }

                    // The back: a lattice in the cover's colour inside a white
                    // border.
                    Component {
                        id: backFace
                        Item {
                            Rectangle {
                                id: backPanel
                                anchors.fill: parent
                                anchors.margins: skin.cw * 0.07
                                radius: skin.cw * 0.035
                                color: skin.backColor
                                clip: true

                                Canvas {
                                    anchors.fill: parent
                                    readonly property color line: Qt.lighter(skin.backColor, 1.45)
                                    onLineChanged: requestPaint()
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        const g = getContext("2d");
                                        g.reset();
                                        g.strokeStyle = line;
                                        g.lineWidth = Math.max(0.6, skin.cw * 0.006);
                                        const s = skin.cw * 0.09;
                                        g.beginPath();
                                        for (let d = -height; d < width + height; d += s) {
                                            g.moveTo(d, 0);
                                            g.lineTo(d + height, height);
                                            g.moveTo(d, height);
                                            g.lineTo(d + height, 0);
                                        }
                                        g.stroke();
                                        g.strokeRect(s * 0.5, s * 0.5, width - s, height - s);
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "★"
                                    color: skin.paper
                                    style: Text.Outline
                                    styleColor: skin.backColor
                                    font { family: "serif"; pixelSize: Math.max(8, Math.round(skin.cw * 0.28)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
