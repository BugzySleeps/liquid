pragma Singleton

import QtQuick
import Quickshell

// Synced lyrics for the playing track from lrclib.net. Only works while something shows them: a
// lyrics widget, or the media panel.
Singleton {
    id: root

    readonly property bool wanted: Widgets.items.some(w => w.type === "lyrics") || Ui.panel === "media"
    property var lines: []          // [{ t: seconds (-1 if unsynced), text }]
    property string status: "idle"  // idle | loading | synced | plain | none | offline
    property int index: -1

    readonly property string track: Media.active && Media.player?.trackTitle ? Media.artist + "|" + Media.player.trackTitle : ""
    onTrackChanged: if (wanted)
        load()
    onWantedChanged: if (wanted)
        load()

    Timer {
        interval: 200
        running: root.wanted && root.status === "synced" && Media.active
        repeat: true
        onTriggered: {
            const pos = (Media.player?.position ?? 0) + 0.2;
            let i = -1;
            for (let j = 0; j < root.lines.length && root.lines[j].t <= pos; j++)
                i = j;
            if (i !== root.index)
                root.index = i;
        }
    }

    function get(url, done) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            let r = null;
            try {
                r = x.status === 200 ? JSON.parse(x.responseText) : null;
            } catch (e) {}
            done(r, x.status);
        };
        x.open("GET", url);
        x.setRequestHeader("User-Agent", "ekitai-quickshell (github.com/BugzySleeps/liquid)");
        x.send();
    }

    function parse(lrc) {
        const out = [];
        for (const l of lrc.split("\n")) {
            const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/);
            if (m)
                out.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3].trim() || "♪" });
        }
        return out;
    }

    function use(d) {
        if (d?.syncedLyrics) {
            lines = parse(d.syncedLyrics);
            status = "synced";
        } else if (d?.plainLyrics) {
            lines = d.plainLyrics.split("\n").filter(l => l.trim()).map(text => ({ t: -1, text }));
            status = "plain";
        } else {
            status = "none";
        }
    }

    function load() {
        lines = [];
        index = -1;
        if (!track) {
            status = "idle";
            return;
        }
        status = "loading";
        const want = track;
        const title = Media.player.trackTitle, artist = Media.artist;
        let q = `artist_name=${encodeURIComponent(artist)}&track_name=${encodeURIComponent(title)}`;
        if (Media.length > 0)
            q += `&duration=${Math.round(Media.length)}`;
        get("https://lrclib.net/api/get?" + q, (d, code) => {
            if (want !== track)
                return;
            if (d) {
                use(d);
                return;
            }
            if (code === 0) {
                status = "offline";
                return;
            }
            // no exact match (often the duration): search instead
            get("https://lrclib.net/api/search?q=" + encodeURIComponent(artist + " " + title), r => {
                if (want !== track)
                    return;
                use(Array.isArray(r) ? (r.find(x => x.syncedLyrics) ?? r[0]) : null);
            });
        });
    }
}
