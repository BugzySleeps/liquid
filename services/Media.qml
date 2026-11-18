pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// The MPRIS player worth showing: the one that's playing, else the first one around.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property bool active: !!player
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || "nothing playing"
    readonly property string artist: player?.trackArtist || ""
    readonly property string album: player?.trackAlbum || ""
    readonly property string art: player?.trackArtUrl || embeddedArt
    readonly property string source: player?.identity || ""
    readonly property real length: player?.length ?? 0
    readonly property string line: artist ? artist + " — " + title : title

    // MPRIS doesn't push position updates, so poll it (fast while playing; slowly while paused, so a
    // seek or a paused track still shows where it is)
    property real position: 0

    Timer {
        running: root.active
        interval: root.playing ? 1000 : 2500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.position = root.player?.position ?? 0
    }

    onPlayerChanged: position = player?.position ?? 0

    // colours from the album art (Settings.artAccent): `rice accent` recolours the shell, the borders and the
    // terminals for the track, and puts the usual colours back when it's off or nothing's playing. With the
    // album wallpaper on as well (Settings.artWall) the wallpaper comes from the cover too (desktop/Wallpaper.qml)
    readonly property bool artWall: Settings.artAccent && Settings.artWall && !homeScene
    // a wallpaper with a scene of its own (desktop/Wallpaper.qml) moves to the music itself: no album wallpaper over it
    property bool homeScene: false
    FileView {
        path: root.sceneOf(Colors.homeWallpaper)
        printErrors: false
        onPathChanged: root.homeScene = false
        onLoaded: root.homeScene = true
        onLoadFailed: root.homeScene = false
    }
    // a wallpaper's scene: <its folder>/.scene/<its name>/scene.qml ("" for none, or the album wallpaper)
    function sceneOf(wall) {
        if (!wall || wall.indexOf("/rice-artwall/") >= 0)
            return "";
        const i = wall.lastIndexOf("/");
        return wall.slice(0, i) + "/.scene/" + wall.slice(i + 1).replace(/\.[^.]*$/, "") + "/scene.qml";
    }
    readonly property string accentFrom: Settings.loaded && Settings.artAccent && active && art ? (artWall ? "wall|" : "") + art : ""
    // unknown at start: a restarted shell can't tell what the last one left up, so the first look always applies
    property string accentNow: "?"
    onAccentFromChanged: accentLater.restart()
    Timer {
        id: accentLater
        interval: 350                            // skipping through tracks doesn't recolour every one
        running: Settings.loaded
        onTriggered: {
            if (!Settings.loaded || root.accentFrom === root.accentNow)
                return;
            root.accentNow = root.accentFrom;
            const wall = root.accentNow.startsWith("wall|");
            const from = wall ? root.accentNow.slice(5) : root.accentNow;
            Quickshell.execDetached(["sh", "-c", '~/.config/rice/rice accent "$@"', "sh", from || "off"].concat(wall ? ["--wall"] : []));
        }
    }

    // cmus doesn't send cover art over MPRIS, so pull the cover out of the file it's playing
    property string embeddedArt: ""
    readonly property string trackKey: (player?.identity ?? "") + "|" + (player?.trackTitle ?? "") + "|" + artist

    onTrackKeyChanged: {
        embeddedArt = "";
        artProc.running = false;
        if (player && !player.trackArtUrl && player.identity.toLowerCase() === "cmus")
            artProc.running = true;
    }

    Process {
        id: artProc
        command: ["sh", "-c", `f=$(cmus-remote -Q 2>/dev/null | sed -n 's/^file //p'); [ -f "$f" ] || exit 1
            d="$XDG_RUNTIME_DIR/ekitai-art"; mkdir -p "$d"; rm -f "$d"/*; o="$d/$(date +%s%N).jpg"
            case "$f" in
                *.flac) metaflac --export-picture-to="$o" "$f" ;;
                *) ffmpeg -v quiet -i "$f" -an -c:v copy -frames:v 1 -f image2 "$o" ;;
            esac 2>/dev/null && [ -s "$o" ] && echo "$o"`]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                root.embeddedArt = "file://" + text.trim()
        }
    }

    function toggle() {
        player?.togglePlaying();
    }

    function next() {
        player?.next();
    }

    function previous() {
        player?.previous();
    }

    function seek(fraction) {
        if (player?.canSeek && length > 0) {
            player.position = fraction * length;
            position = player.position;
        }
    }

    function time(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
}
