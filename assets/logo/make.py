#!/usr/bin/env python3
"""The ekitai logo, a drop falling into rings of ripples: python3 make.py writes the SVGs (and PNGs, with
rsvg-convert) into this folder. The shell draws its own copy (components/Logo.qml) in the theme's colours."""
import subprocess
from pathlib import Path

HERE = Path(__file__).parent
GREEN, BRIGHT = "#5fe878", "#b8f7c4"

DROP = "M128 22 C128 22 103 60 103 80 A25 25 0 0 0 153 80 C153 60 128 22 128 22 Z"
# the rings: (rx, ry, width, dash pattern in percent of the ring, opacity), squashed to lie on the water
RINGS = [(28, 9.5, 7, None, 1.0), (60, 20, 6, "15 2", 0.85), (92, 31, 5, "5 2.2", 0.6), (120, 40.5, 4, "1.4 2", 0.4)]
SMALL = [(52, 16, 13, None, 1.0), (108, 34, 11, None, 0.7)]    # tiny sizes: two solid rings, a bigger drop


def mark(color=GREEN, rings=RINGS, cy=190, trail=True, glow=False, drop=1.0):
    out = []
    if trail:                                    # the drop's fall: two dots between it and the water
        out += [f'<circle cx="128" cy="124" r="4" fill="{color}" opacity=".7"/>',
                f'<circle cx="128" cy="142" r="3" fill="{color}" opacity=".45"/>']
    for rx, ry, w, dash, op in rings:
        d = f' pathLength="100" stroke-dasharray="{dash}"' if dash else ""
        out.append(f'<ellipse cx="128" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="{color}" '
                   f'stroke-width="{w}" opacity="{op}"{d}/>')
    grow = f' transform="translate(128 {22 - 4 * (drop > 1)}) scale({drop}) translate(-128 -22)"' if drop != 1 else ""
    out.append(f'<path d="{DROP}" fill="{color}"{grow}/>')
    g = ' filter="url(#glow)"' if glow else ""
    return f'<g{g}>' + "".join(out) + "</g>"


GLOW = ('<defs><filter id="glow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="5" '
        'result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>')


def svg(w, h, body, bg=None, view=None):
    b = f'<rect width="100%" height="100%" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{view or f"0 0 {w} {h}"}">'
            f'{GLOW}{b}{body}</svg>\n')


files = {
    # the mark alone, transparent; and on black with its glow (the "app icon")
    "logo.svg": svg(256, 256, mark()),
    "logo-glow.svg": svg(256, 256, mark(glow=True), bg="#000"),
    # small sizes (bar, favicon): two solid rings, the drop bigger
    "logo-small.svg": svg(256, 256, mark(rings=SMALL, cy=196, trail=False, drop=1.35)),
    # the wordmark: the mark, then ekitai and 液体 beside it
    "logo-wordmark.svg": svg(760, 256, mark(glow=True)
        + f'<text x="290" y="150" font-family="Departure Mono" font-size="110" fill="{GREEN}" filter="url(#glow)">ekitai</text>'
        + f'<text x="296" y="210" font-family="Noto Sans CJK JP" font-size="40" letter-spacing="18" fill="{GREEN}" opacity=".55">液体</text>',
        bg="#000"),
}
for name, text in files.items():
    (HERE / name).write_text(text)
    size = ["-w", "1520"] if "wordmark" in name else ["-w", "512"]
    subprocess.run(["rsvg-convert", *size, str(HERE / name), "-o", str(HERE / name.replace(".svg", ".png"))], check=True)
print("made", ", ".join(files))
