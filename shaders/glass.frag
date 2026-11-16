#version 440
// Liquid glass, drawn by the shell (no compositor blur): the wallpaper, blurred once (Glass.qml), seen
// through a slab whose rim bends it like a lens, with a little colour fringing, the theme's tint, and light
// catching the edge (bright at the top-left, a fainter bounce at the bottom-right).
//   win: the window's spot on screen (x, y) and size · at: the item's spot on screen when it's drawn off
//   screen (at.z = 1), since then the vertices can't tell · back: 0 when nothing's behind to show (the
//   window's spot isn't known) · edge: 0 when something else cuts the outline (a widget's shape)
layout(location = 0) in vec2 uv;
layout(location = 1) in vec2 inWin;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 win;
    vec4 at;
    vec2 size;
    vec2 screen;
    vec4 tint;
    vec4 light;
    float radius;
    float inset;
    float round;
    float back;
    float edge;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = uv * size;
    vec2 h = size * 0.5 - inset;
    vec2 q = p - size * 0.5;

    // a rounded box (or an ellipse-ish circle): how far inside, and which way is out
    float r = min(radius, min(h.x, h.y));
    vec2 d = abs(q) - (h - r);
    float sd = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
    vec2 n = d.x > 0.0 && d.y > 0.0 ? normalize(d) : (d.x > d.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
    n *= sign(q + 1e-4);
    if (round > 0.5) {
        float R = min(h.x, h.y);
        sd = length(q) - R;
        n = normalize(q + 1e-4);
    }
    if (edge < 0.5) {
        // the shape is cut elsewhere: no edge of its own, just the middle of the slab
        sd = -1e3;
        n = vec2(0.0);
    }
    float inside = clamp(0.5 - sd, 0.0, 1.0);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float depth = -sd;

    // the rim bends what's behind inwards, most at the very edge
    float bezel = clamp(min(h.x, h.y) * 0.45, 4.0, 22.0);
    float e = clamp(1.0 - depth / bezel, 0.0, 1.0);
    vec2 bend = -n * e * e * bezel * 1.1;

    vec2 origin = at.z > 0.5 ? at.xy : win.xy + inWin * win.zw - p;
    vec2 s = (origin + p) / screen;
    vec2 b = bend / screen;
    vec3 col = vec3(texture(source, s + b * 1.15).r, texture(source, s + b).g, texture(source, s + b * 0.85).b);
    // a touch livelier than the wallpaper, like light through glass
    float grey = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(grey), col, 1.25);
    col = mix(tint.rgb, col, back);

    // the theme's tint over it, a bit lighter at the bezel so the edge reads as thickness
    col = mix(col, tint.rgb, tint.a * (1.0 - 0.35 * e * back));

    // light on the edge: a bright line top-left, a fainter one bottom-right, a soft glow just inside
    vec2 L = normalize(vec2(-0.55, -0.85));
    float facing = dot(n, L);
    float line = smoothstep(2.6, 0.0, depth);
    float glow = pow(e, 3.0);
    float spec = line * (0.22 + 0.75 * max(facing, 0.0) + 0.35 * max(-facing, 0.0)) + glow * (0.06 + 0.16 * max(facing, 0.0));
    col += mix(vec3(1.0), light.rgb, 0.35) * spec;
    // and a sheen over the top
    col += vec3(0.05) * pow(1.0 - uv.y, 2.0);

    float a = mix(tint.a, 1.0, back) * inside * qt_Opacity;
    fragColor = vec4(col * a, a);
}
