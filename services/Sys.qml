pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, disk and uptime, read straight from /proc (and df for the disk, once a minute).
Singleton {
    id: root

    property real cpu: 0
    property real mem: 0
    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property real disk: 0
    property string diskText: ""
    property string uptime: ""
    property string user: Quickshell.env("USER") ?? ""
    property string host: ""
    property string os: ""
    property string kernel: ""
    property string cpuModel: ""
    readonly property string shell: (Quickshell.env("SHELL") ?? "").split("/").pop()

    property var _prev: null

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            up.reload();

            const p = stat.text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const idle = p[3] + p[4];
            const total = p.reduce((a, b) => a + b, 0);
            if (root._prev && total > root._prev.total)
                root.cpu = 1 - (idle - root._prev.idle) / (total - root._prev.total);
            root._prev = { idle, total };

            const m = {};
            for (const l of meminfo.text().split("\n")) {
                const r = l.match(/^(\w+):\s+(\d+)/);
                if (r)
                    m[r[1]] = Number(r[2]);
            }
            if (m.MemTotal) {
                root.memTotal = m.MemTotal / 1048576;
                root.memUsed = (m.MemTotal - m.MemAvailable) / 1048576;
                root.mem = root.memUsed / root.memTotal;
            }

            const s = Math.floor(Number(up.text().split(" ")[0]));
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), min = Math.floor(s % 3600 / 60);
            root.uptime = (d ? d + "d " : "") + (h ? h + "h " : "") + min + "m";
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        blockLoading: true
    }

    FileView {
        id: up
        path: "/proc/uptime"
        blockLoading: true
    }

    FileView {
        path: "/etc/os-release"
        blockLoading: true
        onLoaded: root.os = ((text().match(/^PRETTY_NAME=(.*)$/m) ?? [])[1] ?? "").replace(/^["']|["']$/g, "")
    }

    FileView {
        path: "/proc/sys/kernel/osrelease"
        blockLoading: true
        onLoaded: root.kernel = text().trim()
    }

    FileView {
        path: "/proc/cpuinfo"
        blockLoading: true
        onLoaded: root.cpuModel = ((text().match(/^model name\s*:\s*(.+)$/m) ?? [])[1] ?? "").replace(/\((R|TM)\)|CPU|@.*$/g, "").replace(/\s+/g, " ").trim()
    }

    FileView {
        path: "/etc/hostname"
        blockLoading: true
        onLoaded: root.host = text().trim()
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n")[1].trim().split(/\s+/).map(Number);
                root.disk = v[0] / v[1];
                root.diskText = Math.round(v[0] / 1073741824) + " / " + Math.round(v[1] / 1073741824) + " GiB";
            }
        }
    }
}
