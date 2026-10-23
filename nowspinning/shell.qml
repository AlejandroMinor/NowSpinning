//@ pragma UseQApplication
//@ pragma Env QT_LOGGING_RULES=quickshell.io.socket.warning=false
// MPRIS player widget for Hyprland.
//
// This layer is only the window: where it sits, how it's dragged, when it
// hides, when it flips. It doesn't know how to draw anything: drawing is
// the skin's job (see skins/VinylSkin.qml for the contract), and the data
// comes from MprisSource.qml.
//
// Runs as its own instance:  qs -p ~/.config/quickshell/nowspinning
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "skins"

ShellRoot {
    PanelWindow {
        id: win

        // ===============================================================
        // Settings. Loaded from ~/.config/nowspinning/config.json; the values
        // here are just the defaults used when that file doesn't exist.
        // ===============================================================

        // Which output to show on. Matched by connector name, the same name
        // `hyprctl monitors` reports (e.g. "eDP-1", "HDMI-A-1"). Empty
        // string, or a name that isn't currently connected, falls back to
        // whatever the compositor picks on its own, normally the focused
        // output at launch.
        //
        // Changing it is applied live, but not by assigning `screen`
        // directly: moving a layer-shell surface between outputs while it's
        // up doesn't survive the trip. Qt hands the same cached-layer items
        // (the disc, the sheen) to the old window and the new one at once,
        // logs "Cannot use same item on different windows at the same time",
        // and segfaults on the next frame. Taking the window down for one
        // beat and bringing it back up gives it a clean surface to build on
        // the new output instead.
        readonly property var targetScreen: {
            if (!cfg.monitor)
                return null;
            for (const s of Quickshell.screens)
                if (s.name === cfg.monitor)
                    return s;
            return null;
        }

        // No binding on `screen`: `migration` assigns it while the window is
        // down, and a binding would fight that.
        Component.onCompleted: win.screen = win.targetScreen
        onTargetScreenChanged: migration.restart()

        visible: !migration.running

        Timer {
            id: migration
            // Long enough for the compositor to have actually dropped the
            // old surface, short enough not to read as a flicker.
            interval: 60
            onTriggered: win.screen = win.targetScreen
        }

        // Named presets, so config.json can say `"medium"` instead of
        // forcing a guess at a pixel number. `cfg.discSize` still accepts a
        // plain number (as a string, e.g. `"200"`) for anyone who wants an
        // exact size instead of a preset.
        readonly property var sizePresets: ({
            small: 120,
            medium: 170,
            large: 220,
            xl: 280
        })

        readonly property var sizeOrder: ["small", "medium", "large", "xl"]

        // Applies a change that resizes the box (a new size, a new skin)
        // around the widget's center instead of its top-left corner, so it
        // stays under the pointer that just clicked it, and saves it.
        property bool resizing: false
        function keepingCenter(change) {
            const cx = placedX + boxW / 2;
            const cy = placedY + boxH / 2;

            resizing = true;
            change();
            lastBoxW = boxW;
            lastBoxH = boxH;

            const sw = screen ? screen.width : 1920;
            const sh = screen ? screen.height : 1080;
            posX = Math.max(0, Math.min(sw - boxW, cx - boxW / 2));
            posY = Math.max(0, Math.min(sh - boxH, cy - boxH / 2));
            cfg.x = Math.round(posX);
            cfg.y = Math.round(posY);
            configFile.writeAdapter();
            Qt.callLater(() => resizing = false);
        }

        // What the settings page behind the gear offers, in the shape
        // Controls.qml expects. Toggles only show up where they do
        // something: the arm and deck on the vinyl, the ring on round faces,
        // the clear shell on the tapes.
        readonly property var skinOrder: ["vinyl", "cd", "disc", "cassette", "minidisc", "walkman",
                                          "single", "crt", "ascii", "pixel", "polaroid",
                                          "hologram", "foil"]
        readonly property var skinNames: ({
            vinyl: "Vinyl", cd: "CD", disc: "Disc", cassette: "Tape", minidisc: "MD",
            walkman: "Walkman", crt: "CRT", ascii: "ASCII", pixel: "Pixel",
            polaroid: "Polaroid", single: "7\"", hologram: "Holo", foil: "Foil"
        })

        readonly property var settingsOptions: {
            const size = String(cfg.discSize).trim();
            // A value left empty in config.json falls back instead of
            // breaking the whole list.
            const cap = (v, fallback) => {
                const t = String(v || fallback);
                return t[0].toUpperCase() + t.slice(1);
            };
            const toggles = [];
            if (skinName === "vinyl" || skinName === "single")
                toggles.push({ key: "showArm", label: "Arm", on: cfg.showArm });
            if (skinName === "vinyl")
                toggles.push({ key: "showDeck", label: "Deck", on: cfg.showDeck });
            if (ringUsable)
                toggles.push({ key: "ring", label: "Ring", on: progressStyle === "ring" });
            if (skinName === "cd")
                toggles.push({ key: "peekSide", label: "Side: " + cap(cfg.peekSide, "right"), on: false });
            if (skinName === "cassette" || skinName === "walkman")
                toggles.push({ key: "clear", label: "Clear", on: cfg.shellOpacity < 1 });
            // The flat skins' options; the stepped ones show their value and step on click.
            if (skinName === "pixel")
                toggles.push({ key: "pixels", label: "Px: " + cfg.pixels, on: false });
            if (skinName === "ascii") {
                toggles.push({ key: "columns", label: "Cols: " + cfg.columns, on: false });
                toggles.push({ key: "colored", label: "Color", on: cfg.colored });
            }
            if (skinName === "crt") {
                toggles.push({ key: "showBezel", label: "Bezel", on: cfg.showBezel });
                toggles.push({ key: "effect", label: "Glitch: " + cap(cfg.effect, "random"), on: false });
            }
            if (skinName === "polaroid")
                toggles.push({ key: "showStack", label: "Stack", on: cfg.showStack });
            if (skinName === "foil")
                toggles.push({ key: "foilStyle", label: "Foil: " + cap(cfg.foilStyle, "rainbow"), on: false });
            // The light: every skin follows the pointer, most also drift on
            // their own (the discs don't: room light stays put).
            const skinItem = skinLoader.item;
            if (skinItem && skinItem.lightMotion !== undefined)
                toggles.push({ key: "lightMotion", label: "Motion", on: cfg.lightMotion });
            if (skinItem && skinItem.lightTilt !== undefined)
                toggles.push({ key: "lightTilt", label: "Hover", on: cfg.lightTilt });
            if (skinName === "hologram") {
                toggles.push({ key: "holoColor", label: "Color: " + cap(cfg.holoColor, "cyan"), on: false });
                toggles.push({ key: "holoMotion", label: "Motion", on: cfg.holoMotion });
                toggles.push({ key: "holoGlitch", label: "Glitch", on: cfg.holoGlitch });
                toggles.push({ key: "holoOpacity", label: "Alpha: " + Math.round(cfg.holoOpacity * 100) + "%", on: false });
                toggles.push({ key: "holoBase", label: "Base", on: cfg.holoBase });
            }
            toggles.push({ key: "tintFromArt", label: "Tint", on: cfg.tintFromArt });
            toggles.push({ key: "shadow", label: "Shadow", on: cfg.shadow });
            toggles.push({ key: "lyrics", label: "Lyrics", on: cfg.lyrics });
            if (cfg.lyrics) {
                toggles.push({ key: "lyricsLines", label: "Lines: " + cfg.lyricsLines, on: false });
                toggles.push({ key: "lyricsSize", label: "Text: " + cap(cfg.lyricsSize, "medium")[0], on: false });
            }

            return [
                { id: "skin", icon: "skin",
                  items: skinOrder.map(k => ({ key: k, label: skinNames[k], on: k === skinName })) },
                { id: "size", icon: "size",
                  items: sizeOrder.map((k, i) => ({ key: k, label: ["S", "M", "L", "XL"][i], on: k === size })) },
                { id: "toggle", icon: "toggle", items: toggles }
            ];
        }

        // Options that step through values instead of switching on and off.
        readonly property var steps: ({
            peekSide: ["right", "left", "top", "bottom"],
            pixels: [64, 32, 24, 16],
            columns: [32, 48, 64],
            effect: ["random", "slices", "roll", "static", "split", "channel"],
            holoColor: ["cyan", "green", "pink", "amber", "art"],
            holoOpacity: [1, 0.75, 0.5],
            lyricsLines: [3, 1],
            lyricsSize: ["medium", "large", "small"],
            foilStyle: ["rainbow", "gold", "silver", "art"]
        })

        function pickOption(section, key) {
            keepingCenter(() => {
                if (section === "skin")
                    cfg.skin = key;
                else if (section === "size")
                    cfg.discSize = key;
                else if (key === "ring")
                    cfg.progressStyle = cfg.progressStyle === "ring" ? "bar" : "ring";
                else if (key === "clear")
                    cfg.shellOpacity = cfg.shellOpacity < 1 ? 1 : 0.45;
                else if (steps[key]) {
                    const values = steps[key];
                    cfg[key] = values[(values.indexOf(cfg[key]) + 1) % values.length];
                } else
                    cfg[key] = !cfg[key];
            });
        }

        readonly property int discSize: {
            const raw = String(cfg.discSize).trim();
            const asNumber = Number(raw);
            if (raw !== "" && !isNaN(asNumber))
                return Math.round(asNumber);
            return sizePresets[raw] ?? sizePresets.medium;
        }

        readonly property string skinName: cfg.skin

        // The flat skins' options, each bound to its config key of the same
        // name when the skin has it.
        readonly property var flatOptions: ["pixels", "columns", "colored", "showBezel", "effect", "showStack",
                                            "holoColor", "holoMotion", "holoGlitch", "holoOpacity", "holoBase",
                                            "foilStyle", "lightMotion", "lightTilt"]
        function bindFlatOptions(item) {
            for (const key of flatOptions) {
                if (item[key] !== undefined)
                    item[key] = Qt.binding(() => cfg[key]);
            }
        }
        readonly property bool showArm: cfg.showArm
        readonly property bool showDeck: cfg.showDeck

        // "ring" = the wave wraps around the disc. "bar" = it runs straight
        // inside the controls overlay, and only shows up with them.
        readonly property string progressStyle: cfg.progressStyle

        // A square-faced skin can't wear the ring around it, so there the
        // bar isn't a choice, it's the only option.
        readonly property bool ringStyle: progressStyle === "ring" && ringUsable

        // Clicking the ring jumps to that point in the track. Only while it's
        // actually drawn and the player can take it; otherwise the ring's
        // area stays click-through, like the rest of the empty box.
        readonly property bool ringSeekable: ringStyle && source.canSeek

        // The ring's own radius, and how far off it a click still counts.
        readonly property real ringRadius: discSize * 0.535
        readonly property real ringReach: Math.max(6, discSize * 0.05)

        // Disc transparency. This is QML alpha, not a compositor effect: it
        // looks the same whether or not Hyprland's blur is on.
        readonly property real discOpacity: cfg.discOpacity

        // Full-face cover art. Only applies to skins that support it; the
        // vinyl skin doesn't, because that would stop it from looking like
        // a vinyl record.
        readonly property bool artFull: cfg.artFull

        // Reveal the track info card. By default the window flips the whole
        // disc; a skin that knows how to reveal it its own way (a CD sliding
        // out of its case) declares `handlesReveal` and takes over.
        property bool flipped: false

        readonly property bool skinReveals:
            skinLoader.item ? skinLoader.item.handlesReveal === true : false

        // ===============================================================

        readonly property var skins: ({
            "vinyl": vinylSkin,
            "cd": cdSkin,
            "disc": discSkin,
            "cassette": cassetteSkin,
            "minidisc": minidiscSkin,
            "walkman": walkmanSkin,
            "crt": crtSkin,
            "ascii": asciiSkin,
            "pixel": pixelSkin,
            "polaroid": polaroidSkin,
            "single": singleSkin,
            "hologram": hologramSkin,
            "foil": foilSkin
        })

        // The window is bigger than the disc: a skin can ask for extra room
        // around it (the vinyl skin does, for the tonearm), and it doesn't
        // have to be square (a CD case with the disc peeking out is wider
        // than tall). The progress ring also needs room, but only while
        // it's actually being drawn.
        // The drop shadow under the skin needs room around it too, or the
        // window's edge cuts its blur off.
        readonly property int ringBox: ringStyle ? Math.round(discSize * 1.14) : 0
        readonly property int shadowPad: showShadow ? Math.round(discSize * 0.08) : 0

        // When the box grows or shrinks on its own (the shadow's room coming
        // or going, the ring switched on, the config edited by hand), the
        // window moves by half the difference, so the skin stays centered
        // where it was instead of jumping. keepingCenter() does the same for
        // its own changes, which is why those are left alone here.
        //
        // Not while starting up: the config and the skin arrive at different
        // moments, and the saved position already fits the box they make.
        property int lastBoxW: 0
        property int lastBoxH: 0
        property bool settled: false
        property bool recentering: false
        Timer { running: true; interval: 1000; onTriggered: win.settled = true }
        function recenter() {
            const dw = boxW - lastBoxW;
            const dh = boxH - lastBoxH;
            lastBoxW = boxW;
            lastBoxH = boxH;
            if (!settled || resizing || (dw === 0 && dh === 0))
                return;
            // From where it's drawn, not where it's saved: they differ when
            // the saved spot doesn't fit this output. Not written back to
            // the config either: this can run in the middle of a hand edit,
            // and a write then would race it. The next drag or pick saves it.
            const sw = screen ? screen.width : 1920;
            const sh = screen ? screen.height : 1080;
            // Its own flag, not `resizing`: width and height change in two
            // separate notifications, and the second must still get through.
            recentering = true;
            posX = Math.max(0, Math.min(sw - boxW, placedX - dw / 2));
            posY = Math.max(0, Math.min(sh - boxH, placedY - dh / 2));
            Qt.callLater(() => recentering = false);
        }
        onBoxWChanged: recenter()
        onBoxHChanged: recenter()
        readonly property int boxW: Math.max(ringBox,
            (skinLoader.item ? Math.round(skinLoader.item.implicitWidth) : discSize) + 2 * shadowPad)
        readonly property int boxH: Math.max(ringBox,
            (skinLoader.item ? Math.round(skinLoader.item.implicitHeight) : discSize) + 2 * shadowPad)

        // The skin's own bounds, in box coordinates: the box minus whatever
        // room the ring and the shadow add around it.
        readonly property rect skinRect: {
            const skin = skinLoader.item;
            const w = skin ? skin.implicitWidth : discSize;
            const h = skin ? skin.implicitHeight : discSize;
            return Qt.rect(Math.round((boxW - w) / 2), Math.round((boxH - h) / 2),
                           Math.round(w), Math.round(h));
        }

        // ---------------------------------------------------------------
        // The skin's face, in box coordinates.
        //
        // A skin doesn't have to be round, or fill its whole box. It can be
        // a CD case with the disc peeking out beside it. This is where the
        // mouse hit area, the controls overlay, and the track info card all
        // come from, so it's the only thing the window needs to know about
        // a skin's shape.
        // ---------------------------------------------------------------
        readonly property rect face: {
            const skin = skinLoader.item;
            if (!skin || !skin.faceRect)
                return Qt.rect(Math.round((boxW - discSize) / 2),
                               Math.round((boxH - discSize) / 2),
                               discSize, discSize);
            const ox = (boxW - skin.implicitWidth) / 2;
            const oy = (boxH - skin.implicitHeight) / 2;
            return Qt.rect(Math.round(ox + skin.faceRect.x),
                           Math.round(oy + skin.faceRect.y),
                           Math.round(skin.faceRect.width),
                           Math.round(skin.faceRect.height));
        }

        readonly property bool faceIsCircle:
            skinLoader.item ? skinLoader.item.faceIsCircle !== false : true

        // The ring only makes sense around a round face.
        readonly property bool ringUsable: faceIsCircle

        // A skin whose whole box is solid (the vinyl on its turntable) is
        // grabbed and hidden as that box, not as its round face: otherwise
        // the plinth around the record lets clicks fall straight through,
        // and stays on screen when the widget hides against an edge.
        readonly property bool solidBox:
            skinLoader.item ? skinLoader.item.solidBox === true : false
        readonly property bool roundHit: faceIsCircle && !solidBox
        readonly property rect body: solidBox ? skinRect : face

        // A soft shadow under the skin, as if it sat a little above the
        // desktop. Drawn once from the face's outline (the whole object, for
        // a solid one) and blurred once: a disc's outline doesn't change as
        // it spins, so there's nothing to redo every frame. Skins that cast
        // their own (the turntable, the card, the Polaroid) or that
        // shouldn't cast one (light, like the hologram) say `ownShadow`.
        readonly property bool showShadow: cfg.shadow
            && !(skinLoader.item && skinLoader.item.ownShadow === true)
        readonly property rect shadowRect: body

        // How much of the disc still peeks out once it's docked to an edge.
        readonly property int peek: Math.round(discSize * 0.18)

        // How far the content has to shift so only `peek` keeps showing.
        // Measured against the skin's body, which isn't necessarily centered.
        readonly property int hideShiftX: dockX < 0
            ? Math.round(body.x + body.width - peek)
            : Math.round(boxW - body.x - peek)
        readonly property int hideShiftY: dockY < 0
            ? Math.round(body.y + body.height - peek)
            : Math.round(boxH - body.y - peek)

        // ---------------------------------------------------------------
        // Docking to an edge
        // ---------------------------------------------------------------
        // Docked is its own state, set on purpose with a right click, not
        // something worked out from where the widget happens to be. It used
        // to be: dropping a drag inside a magnetic zone along the edges
        // snapped it flush and hid it, so just moving it somewhere near an
        // edge made it jump the rest of the way and vanish. Now a drag only
        // ever moves it, and it lands exactly where it's let go.
        //
        // "" (not docked), "left", "right", "top" or "bottom".
        readonly property string dock: cfg.dock
        readonly property int dockX: dock === "left" ? -1 : (dock === "right" ? 1 : 0)
        readonly property int dockY: dock === "top" ? -1 : (dock === "bottom" ? 1 : 0)

        readonly property bool docked: dockX !== 0 || dockY !== 0
        property bool expanded: false
        readonly property bool collapsed: docked && !expanded

        // The transport controls, shown by a click and hidden by another,
        // or by the pointer leaving. Hovering is left to the skin:
        // the flat ones tilt toward the pointer, and the controls would
        // cover what's tilting.
        property bool controlsOpen: false

        // Sends it to the nearest edge and hides it, or brings it back out.
        // A docked widget that was tapped open just hides again; one that's
        // hidden comes out undocked, flush against the edge it was on.
        function toggleDock() {
            if (docked && expanded) {
                expanded = false;
                return;
            }
            if (docked) {
                posX = placedX;
                posY = placedY;
                cfg.x = Math.round(posX);
                cfg.y = Math.round(posY);
                cfg.dock = "";
                expanded = false;
                configFile.writeAdapter();
                return;
            }
            const sw = screen ? screen.width : 1920;
            const sh = screen ? screen.height : 1080;
            const gaps = [
                { side: "left", gap: placedX },
                { side: "right", gap: sw - boxW - placedX },
                { side: "top", gap: placedY },
                { side: "bottom", gap: sh - boxH - placedY }
            ];
            gaps.sort((a, b) => a.gap - b.gap);
            // The position along the edge is kept, so it comes back out
            // where it went in.
            cfg.x = Math.round(placedX);
            cfg.y = Math.round(placedY);
            cfg.dock = gaps[0].side;
            expanded = false;
            configFile.writeAdapter();
        }

        // Position, as margins from the top-left corner.
        // Real numbers, not integers: dragging accumulates fractional
        // pixels, and rounding them on every step would make it advance in
        // little jumps instead of smoothly.
        //
        // With no saved position, it starts at `cfg.anchor` ("left" by
        // default), a named side instead of raw pixels, so there's no need
        // to hand-calculate where each corner falls on every screen size.
        // The first time it's dragged, this binding breaks on its own and
        // the position starts coming from the mouse instead; that gets
        // saved as x/y, and from then on the anchor is never consulted again.
        readonly property real anchorMargin: Math.round(discSize * 0.32)

        readonly property real anchorX: {
            const sw = screen ? screen.width : 1920;
            switch (cfg.anchor) {
                case "top-right": case "right": case "bottom-right":
                    return sw - boxW - anchorMargin;
                case "top": case "center": case "bottom":
                    return Math.round((sw - boxW) / 2);
                default:   // top-left, left, bottom-left
                    return anchorMargin;
            }
        }

        readonly property real anchorY: {
            const sh = screen ? screen.height : 1080;
            switch (cfg.anchor) {
                case "bottom-left": case "bottom": case "bottom-right":
                    return sh - boxH - anchorMargin;
                case "left": case "center": case "right":
                    return Math.round((sh - boxH) / 2);
                default:   // top-left, top, top-right
                    return anchorMargin;
            }
        }

        property real posX: cfg.x >= 0 ? cfg.x : anchorX
        property real posY: cfg.y >= 0 ? cfg.y : anchorY

        // A saved position belongs to the output it was dragged on. Move to
        // a narrower one, or one that's mounted vertically, and those same
        // coordinates land past its edge: the compositor has nowhere to put
        // the surface and the widget is simply gone, with nothing on screen
        // to say why. So the position is clamped where it's used rather than
        // where it's stored: `posX` stays whatever was saved, ready for the
        // wider output if it comes back, and the widget shows up against the
        // near edge in the meantime.
        // A position that already fits is left alone; one that doesn't comes
        // back a little way in from the edge, rather than flush against it.
        function place(saved, limit) {
            if (saved >= 0 && saved <= limit)
                return saved;
            return saved < 0 ? Math.min(anchorMargin, limit)
                             : Math.max(0, limit - anchorMargin);
        }

        // Docked, the edge wins on its own axis: it stays flush against it
        // on any output, whatever was saved.
        property real placedX: dockX < 0 ? 0
            : dockX > 0 ? (screen ? screen.width : 1920) - boxW
            : place(posX, (screen ? screen.width : 1920) - boxW)
        property real placedY: dockY < 0 ? 0
            : dockY > 0 ? (screen ? screen.height : 1080) - boxH
            : place(posY, (screen ? screen.height : 1080) - boxH)

        // Only the trip to the edge on docking is animated. During a drag
        // the position is already being driven a frame at a time, and
        // easing it there would just add lag on top of the compositor's own.
        Behavior on placedX {
            enabled: !dragger.active && !win.resizing && !win.recentering
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on placedY {
            enabled: !dragger.active && !win.resizing && !win.recentering
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // ---------------------------------------------------------------
        // Data
        // ---------------------------------------------------------------
        MprisSource { id: source; prefer: cfg.preferredPlayer }

        Lyrics { id: lyrics; player: source; enabled: cfg.lyrics }

        LyricsWindow {
            screen: win.screen
            lyrics: lyrics
            widget: Qt.rect(win.placedX + win.body.x, win.placedY + win.body.y,
                            win.body.width, win.body.height)
            lines: cfg.lyricsLines
            scale: Math.max(0.8, win.discSize / 170)
                * ({ small: 0.8, medium: 1, large: 1.3 }[cfg.lyricsSize] ?? 1)
            shown: cfg.lyrics && !win.collapsed && source.available
        }

        ArtAccent {
            id: accent
            source: source.artUrl
            enabled: cfg.tintFromArt
        }

        // The progress indicator's color. Plain white reads fine at half
        // strength; a tint needs more of itself to read as a color at all.
        readonly property color accentStroke: Qt.rgba(accent.accent.r, accent.accent.g,
            accent.accent.b, accent.tinted ? 0.85 : 0.55)

        // Where on the ring the pointer would seek to, 0..1, or -1.
        readonly property real ringPreview: hover.hovered && ringSeekable && !collapsed
            ? ringProgress.fractionAt(hover.point.position.x - stage.x - content.x - ringProgress.x,
                                      hover.point.position.y - stage.y - content.y - ringProgress.y,
                                      ringReach)
            : -1

        // ---------------------------------------------------------------
        // Window
        // ---------------------------------------------------------------
        // The window is exactly the widget's size and gets positioned with
        // margins. Making it screen-sized instead was tried (it would have
        // simplified dragging, see below), but the GPU driver crashes on
        // startup that way: 3 crashes out of every 10 launches, versus 0 out
        // of 15 with a widget-sized window.
        anchors { top: true; left: true }
        margins { left: Math.round(win.placedX); top: Math.round(win.placedY) }
        implicitWidth: win.boxW
        implicitHeight: win.boxH

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nowspinning"

        // Clicks only count where something actually is: the disc while
        // open, the sliver that peeks out while docked. While dragging, the
        // whole screen: the pointer is already captured by then.
        //
        // When docked to an edge, the hit area also includes that sliver
        // even while open: otherwise opening it from the edge leaves the
        // cursor outside the disc, and hover turns off instantly.
        mask: Region {
            shape: win.collapsed || !win.roundHit
                ? RegionShape.Rect : RegionShape.Ellipse
            // A rectangular face (the CD) can have parts sticking out past
            // `face` (the disc peeking out of its case): there, the hit area
            // has to be the whole box, not just the face, or those parts
            // would never receive mouse events.
            //
            // A seekable ring sits outside the face, so the ellipse grows
            // out to it; otherwise clicks on the ring would fall straight
            // through to whatever's behind the widget.
            readonly property real grow: win.ringSeekable
                ? Math.max(0, win.ringRadius + win.ringReach - win.face.width / 2) : 0

            x: stage.x + (win.collapsed
                ? (win.dockX > 0 ? win.boxW - win.peek : 0)
                : (win.roundHit ? win.face.x - grow : win.skinRect.x))
            y: stage.y + (win.collapsed
                ? (win.dockY > 0 ? win.boxH - win.peek : 0)
                : (win.roundHit ? win.face.y - grow : win.skinRect.y))
            width: win.collapsed && win.dockX !== 0 ? win.peek
                : (win.collapsed ? win.boxW
                : (win.roundHit ? win.face.width + 2 * grow : win.skinRect.width))
            height: win.collapsed && win.dockY !== 0 ? win.peek
                : (win.collapsed ? win.boxH
                : (win.roundHit ? win.face.height + 2 * grow : win.skinRect.height))

            // The docked sliver still counts even while open against an edge.
            regions: win.docked && !win.collapsed ? [dockStrip] : []
        }

        Region {
            id: dockStrip
            shape: RegionShape.Rect
            x: stage.x + (win.dockX > 0 ? win.boxW - win.peek : 0)
            y: stage.y + (win.dockY > 0 ? win.boxH - win.peek : 0)
            width: win.dockX !== 0 ? win.peek : win.boxW
            height: win.dockY !== 0 ? win.peek : win.boxH
        }

        // ---------------------------------------------------------------
        // Content. Hidden = shifted outside the window's bounds so the
        // window itself clips it; only `peek` keeps showing.
        // ---------------------------------------------------------------
        Item {
            id: stage
            width: win.boxW
            height: win.boxH
            x: 0
            y: 0

            Item {
                id: content
                width: win.boxW
                height: win.boxH

                x: win.collapsed && win.dockX !== 0 ? win.dockX * win.hideShiftX : 0
                y: win.collapsed && win.dockY !== 0 ? win.dockY * win.hideShiftY : 0

                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                // Under the flip, so it stays put on the "desk" while the
                // card turns over above it.
                Item {
                    visible: win.showShadow
                    x: win.shadowRect.x
                    y: win.shadowRect.y + win.shadowPad * 0.35
                    width: win.shadowRect.width
                    height: win.shadowRect.height
                    opacity: 0.5 * win.discOpacity

                    Rectangle {
                        anchors.fill: parent
                        radius: win.faceIsCircle && !win.solidBox
                            ? width / 2 : Math.round(win.discSize * 0.05)
                        color: "black"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1
                            blurMax: 32
                            autoPaddingEnabled: true
                        }
                    }
                }

                // The flip. The front face is the skin; the back is generic,
                // so the skin never has to know it exists.
                Flipable {
                    id: flipper

                    anchors.centerIn: parent
                    opacity: win.discOpacity
                    width: win.boxW
                    height: win.boxH

                    transform: Rotation {
                        origin.x: flipper.width / 2
                        origin.y: flipper.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: win.flipped && !win.skinReveals ? 180 : 0
                        Behavior on angle {
                            NumberAnimation { duration: 420; easing.type: Easing.InOutCubic }
                        }
                    }

                    front: Item {
                        anchors.fill: parent

                        Loader {
                            id: skinLoader
                            anchors.centerIn: parent
                            sourceComponent: win.skins[win.skinName] ?? vinylSkin

                            onLoaded: {
                                item.size = Qt.binding(() => win.discSize);
                                item.artUrl = Qt.binding(() => source.artUrl);
                                // The vinyl skin flips away and disappears
                                // from view, so freezing its spin while it's
                                // hidden saves CPU with nothing to show for
                                // it. A skin that reveals itself (the CD)
                                // never disappears, so this brake doesn't
                                // apply to it: it would keep "spinning"
                                // out of sight and jump on return. Worse,
                                // without this exception it would also
                                // freeze the moment it slides out, exactly
                                // when you most want to see it spinning.
                                item.playing = Qt.binding(() =>
                                    source.playing && !(win.flipped && !win.skinReveals));
                                if (item.showArm !== undefined)
                                    item.showArm = Qt.binding(() => win.showArm);
                                if (item.showDeck !== undefined)
                                    item.showDeck = Qt.binding(() => win.showDeck);
                                // 0 means "let the skin decide" (a CD spins
                                // much faster than a vinyl record). The
                                // check has to live inside the binding, not
                                // decide once here: config.json loads async,
                                // so at this exact moment cfg.spinDegreesPerSecond
                                // still holds its own placeholder default
                                // (9), not the file's real value yet. A
                                // one-time check here would pass on that
                                // stale 9, bind unconditionally, and then
                                // get overwritten once the real 0 arrives.
                                if (item.spinDegreesPerSecond !== undefined) {
                                    const skinDefault = item.spinDegreesPerSecond;
                                    item.spinDegreesPerSecond = Qt.binding(() =>
                                        cfg.spinDegreesPerSecond > 0
                                            ? cfg.spinDegreesPerSecond : skinDefault);
                                }
                                if (item.artFull !== undefined)
                                    item.artFull = Qt.binding(() => win.artFull);
                                if (item.revealed !== undefined)
                                    item.revealed = Qt.binding(() => win.flipped);
                                if (item.peekSide !== undefined)
                                    item.peekSide = Qt.binding(() => cfg.peekSide);
                                if (item.progress !== undefined)
                                    item.progress = Qt.binding(() => source.progress);
                                if (item.accent !== undefined)
                                    item.accent = Qt.binding(() => accent.accent);
                                if (item.shellOpacity !== undefined)
                                    item.shellOpacity = Qt.binding(() => cfg.shellOpacity);
                                if (item.player !== undefined)
                                    item.player = source;
                                if (item.title !== undefined)
                                    item.title = Qt.binding(() => source.title);
                                if (item.previousArt !== undefined) {
                                    item.previousArt = Qt.binding(() => source.previousArtUrl);
                                    item.previousTitle = Qt.binding(() => source.previousTitle);
                                }
                                win.bindFlatOptions(item);

                                // A skin that starts closed needs a bump to
                                // open. If the skin was switched to live
                                // (data already exists), there's no future
                                // title change left to wait for, so bump it
                                // now instead of leaving it stuck closed.
                                if (item.trackChangeToken !== undefined && source.title !== "")
                                    item.trackChangeToken += 1;
                            }
                        }

                        // Bumps the skin's trackChangeToken (if it has one)
                        // on every real track change, including the very
                        // first: a skin that starts closed uses that same
                        // first bump to reveal itself, instead of popping
                        // open before any real data exists.
                        Connections {
                            target: source

                            function onTitleChanged() {
                                if (skinLoader.item
                                        && skinLoader.item.trackChangeToken !== undefined)
                                    skinLoader.item.trackChangeToken += 1;
                            }
                        }
                    }

                    back: Item {
                        anchors.fill: parent

                        // The back is the same disc, motionless and without
                        // cover art. Flipping to a plain black circle looked
                        // cheap.
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: win.skins[win.skinName] ?? vinylSkin

                            onLoaded: {
                                item.size = Qt.binding(() => win.discSize);
                                item.artUrl = "";
                                item.playing = false;
                                if (item.showArm !== undefined)
                                    item.showArm = false;
                                // The deck stays: flipping the record over
                                // doesn't make the turntable disappear.
                                if (item.showDeck !== undefined)
                                    item.showDeck = Qt.binding(() => win.showDeck);
                                if (item.blankLabel !== undefined)
                                    item.blankLabel = true;
                                // Same tape split as the front, so the
                                // reels don't jump when it flips back.
                                if (item.progress !== undefined)
                                    item.progress = Qt.binding(() => source.progress);
                                if (item.accent !== undefined)
                                    item.accent = Qt.binding(() => accent.accent);
                                if (item.shellOpacity !== undefined)
                                    item.shellOpacity = Qt.binding(() => cfg.shellOpacity);
                                // The back keeps the front's own options: the
                                // CRT's bezel, the hologram's colour and base.
                                win.bindFlatOptions(item);
                            }
                        }

                        TrackInfo {
                            x: win.face.x
                            y: win.face.y
                            width: win.face.width
                            height: win.face.height
                            size: Math.min(win.face.width, win.face.height)
                            source: source
                        }
                    }
                }

                // When a skin reveals itself, the track info card sits on
                // top of its face instead of on the back.
                TrackInfo {
                    x: win.face.x
                    y: win.face.y
                    width: win.face.width
                    height: win.face.height
                    size: Math.min(win.face.width, win.face.height)
                    source: source

                    opacity: win.skinReveals && win.flipped ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 260 } }

                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: win.faceIsCircle ? width / 2
                            : Math.round(win.discSize * 0.06)
                        color: Qt.rgba(0, 0, 0, 0.78)
                        antialiasing: true
                    }
                }

                // How much of the song is left.
                //
                // The ring itself doesn't rotate: the finish line has to
                // stay put to stay readable. What moves is the progress, and
                // the wave's phase.
                // Centered on the face, not the box: on the vinyl deck the
                // record sits left of center.
                ProgressRing {
                    id: ringProgress
                    width: Math.round(win.discSize * 1.14)
                    height: width
                    x: Math.round(win.face.x + win.face.width / 2 - width / 2)
                    y: Math.round(win.face.y + win.face.height / 2 - height / 2)
                    progress: source.progress
                    visible: win.ringStyle && source.duration > 0
                    radius: win.ringRadius
                    preview: win.ringPreview
                    color: win.accentStroke
                    waves: 14

                    // The wave travels while playing and flattens on pause.
                    // When the style is "bar" this isn't even drawn, so
                    // there's nothing to repaint either.
                    flowing: win.ringStyle && source.playing

                    amplitude: source.playing ? win.discSize * 0.014 : 0
                    Behavior on amplitude {
                        NumberAnimation { duration: 550; easing.type: Easing.InOutQuad }
                    }
                    thickness: Math.max(1.5, win.discSize * 0.011)
                    headRadius: Math.max(2, win.discSize * 0.021)
                }

                Controls {
                    id: controls
                    accent: accent.accent
                    accentAlpha: win.accentStroke.a
                    hint: win.ringPreview >= 0
                        ? source.formatClock(win.ringPreview * source.duration) : ""
                    x: win.face.x
                    y: win.face.y
                    width: win.face.width
                    height: win.face.height
                    size: Math.min(win.face.width, win.face.height)
                    circular: win.faceIsCircle
                    showTransport: !(skinLoader.item && skinLoader.item.ownTransport === true)
                    source: source
                    shown: win.controlsOpen && !win.collapsed && !win.flipped
                    showProgress: !win.ringStyle
                }
            }
        }

        SettingsCard {
            id: settingsCard
            host: win
            face: Qt.rect(stage.x + win.face.x, stage.y + win.face.y, win.face.width, win.face.height)
            open: controls.settingsOpen
            options: win.settingsOptions
            skins: win.skins
            artUrl: source.artUrl
            playing: source.playing
            title: source.title
            accent: accent.accent
            onPicked: (section, key) => win.pickOption(section, key)
            onCloseRequested: controls.settingsOpen = false
        }
        // Docking the widget away closes it; otherwise only the gear or its ✕ do.
        Connections {
            target: win
            function onCollapsedChanged() { if (win.collapsed) controls.settingsOpen = false; }
        }

        Component { id: vinylSkin; VinylSkin {} }
        Component { id: cdSkin; CdSkin {} }
        Component { id: discSkin; DiscSkin {} }
        Component { id: cassetteSkin; CassetteSkin {} }
        Component { id: minidiscSkin; MiniDiscSkin {} }
        Component { id: walkmanSkin; WalkmanSkin {} }
        Component { id: crtSkin; CrtSkin {} }
        Component { id: asciiSkin; AsciiSkin {} }
        Component { id: pixelSkin; PixelSkin {} }
        Component { id: polaroidSkin; PolaroidSkin {} }
        Component { id: singleSkin; SingleSkin {} }
        Component { id: hologramSkin; HologramSkin {} }
        Component { id: foilSkin; FoilSkin {} }

        // ---------------------------------------------------------------
        // Interaction
        // ---------------------------------------------------------------
        HoverHandler {
            id: hover
            cursorShape: win.ringPreview >= 0 || controls.barPreview >= 0
                ? Qt.PointingHandCursor : Qt.ArrowCursor
            onHoveredChanged: if (!hovered) win.controlsOpen = false
        }

        WheelHandler {
            target: null   // only care about the event, nothing to transform
            onWheel: (event) => source.nudgeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05)
        }

        // A tap on the docked sliver pulls it out. Once open, a click shows
        // or hides the controls, at once: no waiting to see whether a second
        // one follows. When it does, the second takes the first back and
        // flips the widget to show the track info card. While the controls
        // are up the center doesn't count, that's where the transport
        // buttons live. To hide it against an edge, right click; see
        // `toggleDock`.
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: win.toggleDock()
        }

        TapHandler {
            property bool wasOpen: false
            onTapped: (point) => {
                if (win.collapsed) {
                    win.expanded = true;
                    return;
                }

                // A click on the ring, or on the bar inside the controls,
                // jumps to that point in the track instead of flipping.
                const px = point.position.x - stage.x - content.x;
                const py = point.position.y - stage.y - content.y;
                const onRing = win.ringSeekable
                    ? ringProgress.fractionAt(px - ringProgress.x, py - ringProgress.y,
                                              win.ringReach) : -1;
                // The settings buttons have their own taps.
                if (controls.onSettings(content, px, py))
                    return;

                const onBar = controls.barFraction(content, px, py);
                if (onRing >= 0 || onBar >= 0) {
                    source.seekTo(onRing >= 0 ? onRing : onBar);
                    return;
                }

                // A skin's own keys (the walkman's) take their own taps.
                const skin = skinLoader.item;
                if (skin && skin.ownsPoint && !win.flipped) {
                    const sp = skin.mapFromItem(null, point.position.x, point.position.y);
                    if (skin.ownsPoint(sp.x, sp.y))
                        return;
                }

                // Outside the buttons' zone, which lives at the face's
                // center while the controls are up. Measured as a fraction of
                // the face so it works the same on a disc as on a
                // rectangular case.
                const cx = stage.x + win.face.x + win.face.width / 2;
                const cy = stage.y + win.face.y + win.face.height / 2;
                const dx = (point.position.x - cx) / win.face.width;
                const dy = (point.position.y - cy) / win.face.height;
                // Judged by whether they were up before the first click of
                // a pair: that click opens them, and the second would
                // otherwise land on the buttons it just put there.
                const inCenter = Math.sqrt(dx * dx + dy * dy) <= 0.40;
                if (tapCount >= 2) {
                    if (wasOpen && inCenter)
                        return;
                    win.controlsOpen = wasOpen;
                    win.flipped = !win.flipped;
                    return;
                }
                wasOpen = win.controlsOpen;
                if (wasOpen && inCenter)
                    return;
                win.controlsOpen = !win.controlsOpen;
            }
        }

        // Drag to move. Moving the window works by changing its margins, and
        // the cursor snaps back to the exact point where it grabbed on: the
        // grip stays put relative to the widget.
        DragHandler {
            id: dragger
            target: null
            property point grab

            // Last position the pointer reported. The window is moved from
            // it once per frame, by `stepper`, not here: see below.
            property point pointer

            onActiveChanged: {
                if (active) {
                    grab = centroid.position;
                    pointer = grab;
                    // Start from where it's actually drawn, which isn't
                    // where it's stored if the saved position belongs to a
                    // bigger output; see `placedX`.
                    win.posX = win.placedX;
                    win.posY = win.placedY;
                    // Dragging always undocks it: it goes wherever it's
                    // taken, and only a right click hides it again.
                    cfg.dock = "";
                    win.expanded = false;
                } else {
                    // Stays exactly where it was let go. No snapping.
                    cfg.x = Math.round(win.posX);
                    cfg.y = Math.round(win.posY);
                    configFile.writeAdapter();
                }
            }

            onCentroidChanged: {
                if (active)
                    pointer = centroid.position;
            }
        }

        // The window moves by changing its margins, and the compositor
        // applies that a frame or two later. In the meantime the pointer
        // keeps reporting against the old position, so correcting the full
        // error keeps adding a correction that hasn't landed yet, and the
        // widget shoots off. Applying only a fraction of the error converges
        // instead of diverging. The right fraction depends on how many
        // frames the compositor takes to apply the margin, which can't be
        // queried: with one frame of lag the optimum is 0.5, with two it's
        // 0.33. That's why it's configurable and re-read live.
        //
        // The fraction has to be applied once per *frame*, which is why this
        // is a FrameAnimation and not the drag handler's own signal. Pointer
        // events come in far faster than frames: at 1000Hz there are ~16 of
        // them per frame at 60Hz, all reporting against the same not-yet-
        // applied position, and 16 corrections of 0.45 compound to 1.0. That
        // put the effective gain somewhere between 0.45 and runaway,
        // depending on the mouse's polling rate and how busy the compositor
        // was, which is what made the drag feel unpredictable.
        //
        // On Hyprland none of that is needed: its request socket says where
        // the cursor really is on screen, and the widget goes straight to
        // that minus the point it was grabbed by. No feedback, so nothing to
        // overshoot and bounce back, and it tracks 1:1 like any floating
        // window. Asked once per frame; a reply takes a few hundredths of a
        // millisecond. Elsewhere the env vars are unset and the damped
        // correction below is what runs.
        readonly property string hyprSocket: {
            const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
            const run = Quickshell.env("XDG_RUNTIME_DIR");
            return sig && run ? run + "/hypr/" + sig + "/.socket.sock" : "";
        }

        Socket {
            id: cursorSocket
            path: win.hyprSocket
            property string reply: ""

            // Hyprland answers once and hangs up, so every request is a
            // fresh connection.
            onConnectionStateChanged: {
                if (connected) {
                    reply = "";
                    write("j/cursorpos");
                    flush();
                }
            }

            parser: SplitParser {
                splitMarker: ""
                onRead: (data) => {
                    cursorSocket.reply += data;
                    const m = cursorSocket.reply.match(/"x":\s*(-?\d+)[\s\S]*"y":\s*(-?\d+)/);
                    if (!m)
                        return;
                    // Hyprland hangs up after every reply, which Quickshell
                    // logs as a socket error: sixty a second while dragging.
                    // Hanging up first catches some; the logging rule in
                    // the pragma at the top silences the rest.
                    cursorSocket.connected = false;
                    if (!dragger.active || !win.screen)
                        return;
                    const sw = win.screen.width;
                    const sh = win.screen.height;
                    win.posX = Math.max(0, Math.min(sw - win.boxW,
                        Number(m[1]) - win.screen.x - dragger.grab.x));
                    win.posY = Math.max(0, Math.min(sh - win.boxH,
                        Number(m[2]) - win.screen.y - dragger.grab.y));
                }
            }
        }

        FrameAnimation {
            id: stepper
            running: dragger.active
            onTriggered: {
                if (win.hyprSocket !== "") {
                    if (!cursorSocket.connected)
                        cursorSocket.connected = true;
                    return;
                }
                const sw = win.screen ? win.screen.width : 1920;
                const sh = win.screen ? win.screen.height : 1080;
                const gain = cfg.dragGain;
                win.posX = Math.max(0, Math.min(sw - win.boxW,
                    win.posX + (dragger.pointer.x - dragger.grab.x) * gain));
                win.posY = Math.max(0, Math.min(sh - win.boxH,
                    win.posY + (dragger.pointer.y - dragger.grab.y) * gain));
            }
        }

        // ---------------------------------------------------------------
        // Config. One single file for both settings and the widget's last
        // position: dragging it rewrites the same file.
        // ---------------------------------------------------------------
        readonly property string configDir: Quickshell.env("HOME") + "/.config/nowspinning"

        // FileView doesn't create the directory on its own, and without it
        // the very first write silently fails.
        Process {
            running: true
            command: ["mkdir", "-p", win.configDir]
        }

        FileView {
            id: configFile
            path: win.configDir + "/config.json"
            printErrors: false   // the file doesn't exist the first time
            watchChanges: true
            onFileChanged: reload()

            JsonAdapter {
                id: cfg

                // "small", "medium", "large", "xl", or a plain number as a
                // string (e.g. "200") for an exact pixel size.
                property string discSize: "medium"
                property string skin: "cd"
                property bool showArm: false
                // Vinyl only: the turntable under the record.
                property bool showDeck: false
                property real spinDegreesPerSecond: 9
                property bool artFull: false

                // Which edge of the CD case the disc pokes out from. Only
                // the CD skin uses this; others ignore it.
                property string peekSide: "right"   // right | left | top | bottom

                property string progressStyle: "ring"
                property real discOpacity: 1.0
                property real dragGain: 0.45

                // Tint the progress indicator (and a skin's accents, if it
                // has any) with a color picked out of the cover art.
                property bool tintFromArt: true

                // A soft drop shadow under the skin.
                property bool shadow: true

                // Synced lyrics from lrclib.net under the widget, with the
                // lines around the current one (3) or on its own (1).
                property bool lyrics: true
                property int lyricsLines: 3
                // Text size on top of the widget's own: "small", "medium",
                // "large".
                property string lyricsSize: "medium"

                // Cassette only: how solid its plastic is. Lower for a clear
                // shell that shows the tape inside.
                property real shellOpacity: 1

                // The flat skins. Pixel: squares a side (64, 32, 24, 16).
                // ASCII: columns (32, 48, 64), in the cover's colours or
                // white. CRT: its bezel, and the glitch ("random", "slices",
                // "roll", "static", "split", "channel"). Polaroid: the last
                // track's photo left underneath. Hologram: its colour ("cyan",
                // "green", "pink", "amber", "art"), motion, dropouts and
                // how solid it is (1, 0.75, 0.5).
                // Foil: its finish ("rainbow", "gold", "silver", "art").
                // Every skin: the light (a tilt, a glint, a sheen) drifting
                // on its own while playing, and following the pointer.
                property int pixels: 64
                property int columns: 32
                property bool colored: true
                property bool showBezel: true
                property string effect: "random"
                property bool showStack: true
                property string holoColor: "cyan"
                property bool holoMotion: true
                property bool holoGlitch: true
                property real holoOpacity: 1
                property bool holoBase: true
                property string foilStyle: "rainbow"
                property bool lightMotion: true
                property bool lightTilt: true

                // Edge it's docked to and hidden against: "", "left",
                // "right", "top" or "bottom". Set by right clicking it.
                property string dock: ""

                // MPRIS bus name; see MprisSource.qml's `prefer` for what
                // this actually does.
                property string preferredPlayer: "org.mpris.MediaPlayer2.spotify"

                // Which output to appear on, by connector name (see
                // `hyprctl monitors`). Empty = let the compositor pick.
                property string monitor: ""

                // Where it starts when there's no saved x/y: "top-left",
                // "top", "top-right", "left", "center", "right",
                // "bottom-left", "bottom", "bottom-right".
                property string anchor: "left"

                // -1 = unset; falls back to the default value.
                property int x: -1
                property int y: -1
            }
        }
    }
}
