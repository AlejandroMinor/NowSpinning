# NowSpinning

A floating MPRIS widget for Hyprland, built on Quickshell. Shows the current track as a spinning physical-media skin, a vinyl record or a CD, with transport controls on hover.

It's a player *client* only: it displays and controls whatever MPRIS player is already running. It doesn't play audio, manage a library, or handle a queue.

## Why

Just for fun, really. This is for anyone who likes seeing the cover art of whatever they're currently listening to, more than it's meant to be a serious tool. Spotify's own mini player is minimal, but not something nice to look at, and that's what actually pushed this into existing: something with actual presence instead of a flat progress bar. An object with weight and motion. Grooves that catch light, a tonearm that lifts and lowers, a CD that spins inside its case, all built to be easy to extend with new skins later.

## Requirements

- A Wayland compositor implementing `wlr-layer-shell`. Developed on Hyprland; see Compatibility.
- [`quickshell`](https://quickshell.org) 0.3.1 or newer. It pulls in Qt6 itself (base, declarative, wayland, svg), so there's nothing to install separately for that.
- `qt6-5compat`, for the `Qt5Compat.GraphicalEffects` import in `parts/Sheen.qml`. Quickshell doesn't depend on it, so on a clean system it won't already be there.
- An MPRIS-capable player. NowSpinning displays and controls whatever is already running; it doesn't play audio itself.

## Install

```sh
sudo pacman -S --needed quickshell qt6-5compat
```

That's Arch; see quickshell.org for other distros.

Clone this repo, then symlink it into Quickshell's config directory:

```sh
mkdir -p ~/.config/quickshell && ln -sfn "$(pwd)/nowspinning" ~/.config/quickshell/nowspinning && ls -l ~/.config/quickshell/nowspinning
```

That last `ls` should print the link pointing back into this repo.

Run it:

```sh
qs -p ~/.config/quickshell/nowspinning
```

Or symlink the bundled toggle script, which starts the widget if it isn't running and kills it if it is, the same command either way. The first link makes `nowspinning` a command on your PATH, for a terminal or a Hyprland keybind. The second one is optional: it adds a desktop entry, so NowSpinning also shows up by name and icon in your application menu and in launchers like rofi or wofi.

```sh
mkdir -p ~/.local/bin && ln -sfn "$(pwd)/bin/nowspinning" ~/.local/bin/nowspinning
mkdir -p ~/.local/share/applications && ln -sfn "$(pwd)/desktop/nowspinning.desktop" ~/.local/share/applications/nowspinning.desktop
nowspinning
```

To start it with your session, add a line to your existing `hl.on("hyprland.start", ...)` block in your Lua config, the same way you'd autostart any other program:

```lua
hl.on("hyprland.start", function()
    -- ...whatever else you already autostart here...
    hl.exec_cmd("nowspinning")
end)
```

If you don't have that block yet, the whole thing is what goes in your config. On a plain `hyprland.conf` setup, the equivalent is `exec-once = nowspinning`.

Optionally, bind a key to `nowspinning` in your Hyprland keybindings for a manual toggle.

## Config

Lives at `~/.config/nowspinning/config.json`, reloaded live on save. See `config.example.json` for the full set of defaults.

| Key | Default | Meaning |
|---|---|---|
| `skin` | `"cd"` | `"vinyl"`, `"cd"` (the disc in its jewel case), or `"disc"` (the same CD on its own, no case) |
| `discSize` | `"medium"` | `"small"` (120px), `"medium"` (170), `"large"` (220), or `"xl"` (280); an exact pixel size also works as a string, e.g. `"200"`. Everything else scales from this |
| `showArm` | `false` | Tonearm on the vinyl skin; the disc skins ignore it |
| `spinDegreesPerSecond` | `9` | Rotation speed; `0` lets the skin pick its own (vinyl: 9, CD: 30) |
| `artFull` | `false` | Full-face cover art, on skins that support it |
| `progressStyle` | `"ring"` | `"ring"` around the disc, or `"bar"` inside the controls overlay (forced on square-faced skins) |
| `discOpacity` | `1.0` | Disc transparency, 0 to 1 |
| `dragGain` | `0.45` | How tightly dragging tracks the cursor; see Limitations |
| `anchor` | `"left"` | Starting *screen* position when no `x`/`y` is saved: `top-left`, `top`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom`, `bottom-right` |
| `peekSide` | `"right"` | CD skin only: which edge of the case the disc pokes out from. `"right"`, `"left"`, `"top"`, or `"bottom"`. Independent of `anchor`; combine freely |
| `monitor` | `""` | Which output to appear on, by connector name (`hyprctl monitors`), e.g. `"eDP-1"`. Empty, or a name that isn't connected, means let the compositor pick. Applied live: the widget hides for a beat and comes back on the new output |
| `preferredPlayer` | `"org.mpris.MediaPlayer2.spotify"` | MPRIS bus name that wins when more than one player is running, even while paused. Empty string means no preference, so whichever player is actually playing wins instead |
| `x`, `y` | `-1` | Saved position; `-1` means "use `anchor`". Overwritten automatically when dragged |

## Usage

- **Drag** anywhere on the disc to move it.
- **Drop near a screen edge** to dock and auto-hide it, leaving a sliver showing. Tap the sliver to bring it back out.
- **Tap the disc's rim** (not the buttons) to reveal the track info: title, artist, album, elapsed time.
- **Scroll** over the disc to change volume.
- **Hover** to reveal transport controls (previous / play-pause / next).

Cover art crossfades in on its own, and switches tracks smoothly rather than popping. On the CD skin specifically, a real track change also pulls the disc back into the case for a moment before it settles back out, showing the bare disc where the cover normally sits.

There's no close button, by design. You close it the same way you opened it, since `nowspinning` is a toggle: run it again in a terminal, hit your keybind, or click NowSpinning again in your application menu or launcher, since the desktop entry runs that same command.

If you started it with plain `qs` instead, or the script isn't linked, kill it directly:

```sh
qs kill -c nowspinning
```

`qs list --all` shows what's running, and `qs kill` also takes `-i <instance id>` or `--pid <pid>`.

## Compatibility

Works with any MPRIS-compliant player exposed on the session D-Bus. Developed and tested against Spotify. `playerctld` is filtered out specifically, since it's a proxy for other players and would show up as a duplicate entry.

Developed and tested only on Hyprland, on Arch. Nothing in the code calls Hyprland specifically, though: the widget is placed with `Quickshell.Wayland`, against the `wlr-layer-shell` protocol, which any wlroots-based compositor implements (Sway, river, and others). It should run there the same way, down to the `monitor` config value, which is just a connector name like `hyprctl monitors` reports, the same kind of name `swaymsg -t get_outputs` reports on Sway. Wayland only, not X11: there's no fallback for compositors or sessions without a layer-shell implementation, GNOME's among them.

## Limitations

- Single player at a time: `preferredPlayer` wins if it's running, otherwise whichever MPRIS player is currently playing.
- No seek-by-click on the progress indicator, it's read-only.
- No queue, library, or playlist view; MPRIS doesn't expose those.
- Playback position is interpolated between polls, not read continuously, so it can drift by a fraction of a second before the next correction.
- Drag tracking uses a damping factor (`dragGain`) rather than 1:1 cursor following, because the exact 1:1 approach (a screen-sized window) crashes the GPU driver intermittently on this stack. The damped version is stable but not pixel-perfect during the drag itself.
- A monitor's orientation is read when the widget starts. Rotating one while it's running isn't picked up: neither Quickshell nor Qt updates the screen size it reported at startup, and catching it would mean listening to Hyprland's IPC, which would tie this to Hyprland specifically. Restart it (`nowspinning` twice) after rotating a monitor. Starting on a rotated output, or moving to one via `monitor`, works fine: the widget gets the rotated dimensions and places itself against them.
- CPU use is near 0% while paused, and roughly 4 to 10% of one core while spinning, depending on skin and progress style.
