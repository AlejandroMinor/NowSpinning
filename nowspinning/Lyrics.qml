// Synced lyrics for whatever is playing, from LRCLIB (lrclib.net): free, no
// account, no key.
//
// Looked up by artist, title, album and length; LRCLIB matches the length
// within a couple of seconds, so a radio edit and the album cut can come
// back as different entries. When that exact lookup finds nothing, a plain
// search on artist and title gets one more try. Only synced lyrics count:
// plain ones have no timing to follow along with.
//
// Kept per track in memory, so going back to a song doesn't ask again.
// LRCLIB answers 503 when it's busy; that's retried a few times, spaced out.
import QtQuick

Item {
    id: root

    property var player             // MprisSource
    property bool enabled: true

    // How far ahead of the audio a line switches, in seconds. A beat early
    // reads better than a beat late.
    property real lead: 0.25

    // "idle" | "loading" | "synced" | "none"
    property string status: "idle"
    property var lines: []          // [{ t, text }], by time

    readonly property int index: {
        if (status !== "synced" || !player)
            return -1;
        const now = player.position + lead;
        let lo = 0, hi = lines.length - 1, found = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].t <= now) { found = mid; lo = mid + 1; }
            else hi = mid - 1;
        }
        return found;
    }

    function lineAt(i) {
        return i >= 0 && i < lines.length ? lines[i].text : "";
    }
    readonly property string previous: lineAt(index - 1)
    readonly property string current: lineAt(index)
    readonly property string next: lineAt(index + 1)

    readonly property string key: player && player.title !== ""
        ? (player.artist + "\u0001" + player.title).toLowerCase() : ""

    property var cache: ({})
    property int token: 0           // drops replies for a track that's gone
    property int retries: 0

    // "[01:23.45] text", possibly several stamps on one line.
    function parse(lrc) {
        const out = [];
        for (const raw of String(lrc).split("\n")) {
            const stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            const times = [];
            let end = 0, m;
            while ((m = stamp.exec(raw)) !== null) {
                times.push(Number(m[1]) * 60 + Number(m[2]));
                end = stamp.lastIndex;
            }
            const text = raw.slice(end).trim();
            for (const t of times)
                out.push({ t: t, text: text });
        }
        out.sort((a, b) => a.t - b.t);
        return out;
    }

    function request(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                done(xhr.status, xhr.responseText);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function settle(forKey, found) {
        cache[forKey] = found;
        if (forKey !== key)
            return;
        lines = found;
        status = found.length > 0 ? "synced" : "none";
    }

    function lookup() {
        const forKey = key;
        const mine = ++token;
        const q = encodeURIComponent;
        let url = "https://lrclib.net/api/get?artist_name=" + q(player.artist)
            + "&track_name=" + q(player.title);
        if (player.album !== "")
            url += "&album_name=" + q(player.album);
        if (player.duration > 0)
            url += "&duration=" + Math.round(player.duration);

        request(url, (code, body) => {
            if (mine !== token)
                return;
            if (code === 503 && retries < 3) {
                retries++;
                retry.restart();
                return;
            }
            let entry = null;
            try { entry = code === 200 ? JSON.parse(body) : null; } catch (e) {}
            if (entry && entry.syncedLyrics) {
                settle(forKey, parse(entry.syncedLyrics));
                return;
            }
            // Second try: a looser search, the first hit with timing.
            request("https://lrclib.net/api/search?q=" + q(player.artist + " " + player.title),
                    (code2, body2) => {
                if (mine !== token)
                    return;
                let hits = [];
                try { hits = code2 === 200 ? JSON.parse(body2) : []; } catch (e) {}
                const hit = hits.find(h => h.syncedLyrics);
                settle(forKey, hit ? parse(hit.syncedLyrics) : []);
            });
        });
    }

    function refresh() {
        token++;
        retries = 0;
        if (!enabled || key === "") {
            status = "idle";
            lines = [];
            return;
        }
        const cached = cache[key];
        if (cached !== undefined) {
            lines = cached;
            status = cached.length > 0 ? "synced" : "none";
            return;
        }
        status = "loading";
        lines = [];
        settleTimer.restart();
    }

    // Titles and artists don't always change together: wait for both.
    Timer { id: settleTimer; interval: 400; onTriggered: root.lookup() }
    Timer { id: retry; interval: 3000; onTriggered: root.lookup() }

    onKeyChanged: refresh()
    onEnabledChanged: refresh()
}
