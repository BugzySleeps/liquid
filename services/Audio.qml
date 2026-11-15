pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // the output the sound is actually going to: apps (cmus) can sit on a different output than the
    // default, and the volume should follow the sound. Same rule as ~/.config/rice/active-sink:
    // the output of a playing stream, else of a paused one, else the default.
    readonly property var streamLinks: Pipewire.linkGroups.values.filter(l => l.source?.isStream && l.target?.isSink && !l.target.isStream)
    readonly property PwNode playingSink: (streamLinks.find(l => l.state === PwLinkState.Active) ?? streamLinks[0])?.target ?? null
    readonly property PwNode sink: playingSink ?? Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    readonly property bool ready: !!sink?.audio
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string icon: muted ? "󰖁" : volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾"

    function setVolume(v) {
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function nudge(step) {
        setVolume(volume + step);
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
}
