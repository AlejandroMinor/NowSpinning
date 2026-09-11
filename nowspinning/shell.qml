//@ pragma UseQApplication
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

        readonly property int discSize: {
            const raw = String(cfg.discSize).trim();
            const asNumber = Number(raw);
            if (raw !== "" && !isNaN(asNumber))
                return Math.round(asNumber);
            return sizePresets[raw] ?? sizePresets.medium;
        }

        readonly property string skinName: cfg.skin
        readonly property bool showArm: cfg.showArm

        // "ring" = the wave wraps around the disc. "bar" = it runs straight
        // inside the controls overlay, and only shows up on hover.
        readonly property string progressStyle: cfg.progressStyle

        // A square-faced skin can't wear the ring around it, so there the
        // bar isn't a choice, it's the only option.
        readonly property bool ringStyle: progressStyle === "ring" && ringUsable

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
            "disc": discSkin
        })

        // The window is bigger than the disc: a skin can ask for extra room
        // around it (the vinyl skin does, for the tonearm), and it doesn't
        // have to be square (a CD case with the disc peeking out is wider
        // than tall). The progress ring also needs room, but only while
        // it's actually being drawn.
        readonly property int ringBox: ringStyle ? Math.round(discSize * 1.14) : 0
        readonly property int boxW: Math.max(ringBox,
            skinLoader.item ? Math.round(skinLoader.item.implicitWidth) : discSize)
        readonly property int boxH: Math.max(ringBox,
            skinLoader.item ? Math.round(skinLoader.item.implicitHeight) : discSize)

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

        // How much of the disc still peeks out once it's docked to an edge.
        readonly property int peek: Math.round(discSize * 0.18)

        // How far the content has to shift so only `peek` keeps showing.
        // Measured against the skin's face, which isn't necessarily centered.
        readonly property int hideShiftX: dockX < 0
            ? Math.round(face.x + face.width - peek)
            : Math.round(boxW - face.x - peek)
        readonly property int hideShiftY: dockY < 0
            ? Math.round(face.y + face.height - peek)
            : Math.round(boxH - face.y - peek)

        // ---------------------------------------------------------------
        // Docking to an edge
        // ---------------------------------------------------------------
        // Magnetic zone around the edges. Releasing a drag inside it snaps
        // the widget to that edge and hides it; with a hard 4px threshold
        // you had to drop it exactly on the pixel, which felt fiddly. Too
        // wide is worse the other way, though: the snap is a jump of the
        // whole zone's width, so a big zone means letting go anywhere near
        // an edge yanks the widget somewhere you didn't put it. As a
        // fraction of the disc, so it means the same thing at every size,
        // and `0` turns the magnet off and leaves the drop where you left it.
        readonly property int edgeSlack:
            Math.round(discSize * Math.max(0, cfg.edgeMagnet))

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
        // Deliberately not tied to `edgeSlack`: turning the magnet down
        // shouldn't also start the widget flush against the screen edge.
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

        // Only the snap on release is animated. During a drag the position
        // is already being driven a frame at a time, and easing it there
        // would just add lag on top of the compositor's own.
        Behavior on posX {
            enabled: !dragger.active
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on posY {
            enabled: !dragger.active
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // A saved position belongs to the output it was dragged on. Move to
        // a narrower one, or one that's mounted vertically, and those same
        // coordinates land past its edge: the compositor has nowhere to put
        // the surface and the widget is simply gone, with nothing on screen
        // to say why. So the position is clamped where it's used rather than
        // where it's stored: `posX` stays whatever was saved, ready for the
        // wider output if it comes back, and the widget shows up against the
        // near edge in the meantime.
        // Landing exactly on the edge would drop it inside the magnet zone,
        // so it would come back collapsed to a sliver against an edge it was
        // never docked to, which just reads as "it didn't start". A position
        // that already fits is left alone, dock and all.
        function place(saved, limit) {
            if (saved >= 0 && saved <= limit)
                return saved;
            return saved < 0 ? Math.min(anchorMargin, limit)
                             : Math.max(0, limit - anchorMargin);
        }

        readonly property real placedX:
            place(posX, (screen ? screen.width : 1920) - boxW)
        readonly property real placedY:
            place(posY, (screen ? screen.height : 1080) - boxH)

        readonly property int dockX: placedX <= edgeSlack ? -1
            : (screen && placedX + boxW >= screen.width - edgeSlack ? 1 : 0)
        readonly property int dockY: placedY <= edgeSlack ? -1
            : (screen && placedY + boxH >= screen.height - edgeSlack ? 1 : 0)

        readonly property bool docked: dockX !== 0 || dockY !== 0
        property bool expanded: false
        readonly property bool collapsed: docked && !expanded

        // ---------------------------------------------------------------
        // Data
        // ---------------------------------------------------------------
        MprisSource { id: source; prefer: cfg.preferredPlayer }

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
            shape: win.collapsed || !win.faceIsCircle
                ? RegionShape.Rect : RegionShape.Ellipse
            // A rectangular face (the CD) can have parts sticking out past
            // `face` (the disc peeking out of its case): there, the hit area
            // has to be the whole box, not just the face, or those parts
            // would never receive mouse events.
            x: stage.x + (win.collapsed
                ? (win.dockX > 0 ? win.boxW - win.peek : 0)
                : (win.faceIsCircle ? win.face.x : 0))
            y: stage.y + (win.collapsed
                ? (win.dockY > 0 ? win.boxH - win.peek : 0)
                : (win.faceIsCircle ? win.face.y : 0))
            width: win.collapsed && win.dockX !== 0 ? win.peek
                : (win.collapsed ? win.boxW
                : (win.faceIsCircle ? win.face.width : win.boxW))
            height: win.collapsed && win.dockY !== 0 ? win.peek
                : (win.collapsed ? win.boxH
                : (win.faceIsCircle ? win.face.height : win.boxH))

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
                                if (item.blankLabel !== undefined)
                                    item.blankLabel = true;
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
                ProgressRing {
                    anchors.fill: parent
                    progress: source.progress
                    visible: win.ringStyle && source.duration > 0
                    radius: win.discSize * 0.535
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
                    x: win.face.x
                    y: win.face.y
                    width: win.face.width
                    height: win.face.height
                    size: Math.min(win.face.width, win.face.height)
                    circular: win.faceIsCircle
                    source: source
                    shown: hover.hovered && !win.collapsed && !win.flipped
                    showProgress: !win.ringStyle
                }
            }
        }

        Component { id: vinylSkin; VinylSkin {} }
        Component { id: cdSkin; CdSkin {} }
        Component { id: discSkin; DiscSkin {} }

        // ---------------------------------------------------------------
        // Interaction
        // ---------------------------------------------------------------
        HoverHandler { id: hover }

        WheelHandler {
            target: null   // only care about the event, nothing to transform
            onWheel: (event) => source.nudgeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05)
        }

        // A tap on the docked sliver pulls it out. Once open, a tap on the
        // disc's rim flips it and shows the track info card. The center
        // doesn't count, that's where the transport buttons live. To hide
        // it again, drag it back to an edge; that's where the magnet is.
        TapHandler {
            onTapped: (point) => {
                if (win.collapsed) {
                    win.expanded = true;
                    return;
                }

                // Outside the buttons' zone, which lives at the face's
                // center. Measured as a fraction of the face so it works the
                // same on a disc as on a rectangular case.
                const cx = stage.x + win.face.x + win.face.width / 2;
                const cy = stage.y + win.face.y + win.face.height / 2;
                const dx = (point.position.x - cx) / win.face.width;
                const dy = (point.position.y - cy) / win.face.height;
                if (Math.sqrt(dx * dx + dy * dy) <= 0.40)
                    return;

                win.flipped = !win.flipped;
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
                    win.expanded = true;   // dragging always reveals it
                } else {
                    // Magnet: releasing near an edge snaps it the rest of
                    // the way there. Worked out into locals first, because
                    // the snap is animated: reading `win.posX` back right
                    // after setting it would still give the drop point, and
                    // that's the value that would get saved.
                    const sw = win.screen ? win.screen.width : 1920;
                    const sh = win.screen ? win.screen.height : 1080;
                    let restX = win.posX;
                    let restY = win.posY;
                    if (restX <= win.edgeSlack)
                        restX = 0;
                    else if (restX >= sw - win.boxW - win.edgeSlack)
                        restX = sw - win.boxW;
                    if (restY <= win.edgeSlack)
                        restY = 0;
                    else if (restY >= sh - win.boxH - win.edgeSlack)
                        restY = sh - win.boxH;

                    win.posX = restX;
                    win.posY = restY;
                    cfg.x = Math.round(restX);
                    cfg.y = Math.round(restY);
                    configFile.writeAdapter();
                    // Parking it against an edge is what hides it.
                    win.expanded = !win.docked;
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
        FrameAnimation {
            id: stepper
            running: dragger.active
            onTriggered: {
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
                property real spinDegreesPerSecond: 9
                property bool artFull: false

                // Which edge of the CD case the disc pokes out from. Only
                // the CD skin uses this; others ignore it.
                property string peekSide: "right"   // right | left | top | bottom

                property string progressStyle: "ring"
                property real discOpacity: 1.0
                property real dragGain: 0.45

                // Width of the magnetic zone along each screen edge, as a
                // fraction of the disc. 0 disables it.
                property real edgeMagnet: 0.05

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
