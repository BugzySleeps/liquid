pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// What the glass look (Look.glass) shows through: the wallpaper, blurred once per wallpaper into a small
// picture (~/.cache/ekitai/glass), instead of Hyprland blurring the screen every frame. Glass surfaces
// (components/GlassFill.qml) show their bit of it, so they look onto the wallpaper even over windows.
Singleton {
    id: root

    readonly property var screen: Quickshell.screens[0]
    readonly property string dir: Quickshell.env("HOME") + "/.cache/ekitai/glass"
    property string backdrop: ""                 // file:// path of the blurred wallpaper, "" until it's made
    // how blurred, in screen pixels (Look.tune.frost); light frosts keep more detail (a half-size picture)
    readonly property int blur: Math.round(4 + 36 * Look.tune.frost)
    readonly property string wanted: Colors.wallpaper && screen ? Colors.wallpaper + "|" + screen.width + "x" + screen.height + "|" + blur : ""

    // a frost slider dragging shouldn't make a picture per step
    onWantedChanged: soon.restart()
    Timer {
        id: soon
        interval: 250
        onTriggered: root.make()
    }
    Component.onCompleted: make()
    function make() {
        if (!wanted || maker.running)
            return;
        maker.made = wanted;
        maker.command = ["python3", "-c", maker.script, Colors.wallpaper, String(screen.width), String(screen.height), dir, String(blur)];
        maker.running = true;
    }
    Process {
        id: maker
        property string made
        // crop like the wallpaper (it fills the screen), shrink (a quarter, half for a light frost), blur; kept,
        // keyed by file, size and blur
        readonly property string script: "
import sys, os, hashlib
from PIL import Image, ImageFilter
src, W, H, out, B = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], int(sys.argv[5])
os.makedirs(out, exist_ok=True)
key = hashlib.sha1(f'{src}|{os.path.getmtime(src)}|{W}x{H}|{B}'.encode()).hexdigest()[:16]
f = 2 if B < 16 else 4
path = os.path.join(out, key + '.png')
if not os.path.exists(path):
    im = Image.open(src).convert('RGB')
    k = max(W / im.width, H / im.height)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BILINEAR)
    l, t = (im.width - W) // 2, (im.height - H) // 2
    im = im.crop((l, t, l + W, t + H)).resize((W // f, H // f), Image.LANCZOS)
    im = im.filter(ImageFilter.GaussianBlur(B / f))
    im.save(path + '.tmp.png')
    os.replace(path + '.tmp.png', path)
print(path)
"
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                root.backdrop = "file://" + text.trim()
        }
        onExited: if (made !== root.wanted)
            root.make()                          // it changed again meanwhile
    }

    // where a shell window sits on its screen (layer windows aren't told): from how it's anchored, below
    // the bar's space unless it ignores it. null for anything else (a normal window).
    readonly property int reserved: Ui.barVisible ? Style.barHeight + Style.gap : 0
    function origin(win) {
        if (!win || win.anchors === undefined || win.margins === undefined)
            return null;
        const sw = win.screen?.width ?? screen.width, sh = win.screen?.height ?? screen.height;
        const top = win.exclusionMode === ExclusionMode.Ignore ? 0 : reserved;
        const a = win.anchors, m = win.margins, w = win.width, h = win.height;
        return Qt.point(a.left ? m.left : a.right ? sw - w - m.right : (sw - w) / 2,
            a.top ? top + m.top : a.bottom ? sh - h - m.bottom : top + (sh - top - h) / 2);
    }
}
