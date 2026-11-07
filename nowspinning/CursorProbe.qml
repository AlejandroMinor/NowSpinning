// Where the cursor is on screen, for dragging the widget 1:1 (see the drag
// in shell.qml). A pointer event only says where the cursor is relative to
// the widget; Hyprland's request socket says where it is on screen.
//
// `ask()` and `moved` answers, in the compositor's layout coordinates.
// `available` is false off Hyprland, where nothing answers.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: probe

    readonly property bool available: socketPath !== ""
    signal moved(real cursorX, real cursorY)

    readonly property string socketPath: {
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        const run = Quickshell.env("XDG_RUNTIME_DIR");
        return sig && run ? run + "/hypr/" + sig + "/.socket.sock" : "";
    }

    function ask() {
        if (!socket.connected)
            socket.connected = true;
    }

    Socket {
        id: socket
        path: probe.socketPath
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
                socket.reply += data;
                const m = socket.reply.match(/"x":\s*(-?\d+)[\s\S]*"y":\s*(-?\d+)/);
                if (!m)
                    return;
                // Hyprland hangs up after every reply, which Quickshell
                // logs as a socket error: sixty a second while dragging.
                // Hanging up first catches some; the logging rule in the
                // pragma at the top of shell.qml silences the rest.
                socket.connected = false;
                probe.moved(Number(m[1]), Number(m[2]));
            }
        }
    }
}
