#version 440
// Liquid glass, drawn by the shell (no compositor blur): the wallpaper, blurred once (Glass.qml), seen
// through a slab whose rounded rim bends it like a lens (a squircle-ish bevel: hardly at all inside, sharply at
// the very edge), with a little colour fringing there, livelier colour, the tint, and light catching the rim
// (brightest where it faces the light and the corner opposite, like macOS's glass).
//   win: the window's spot on screen (x, y) and size · at: the item's spot on screen when it's drawn off
//   screen (at.z = 1), since then the vertices can't tell · back: 0 when nothing's behind to show (the
//   window's spot isn't known) · edge: 0 when something else cuts the outline (a widget's shape)
//   tune: bend (how strongly the rim refracts), shine (light on the rim), saturation, 0
//   wave: squiggle's outline, so the glass (and its rim of light) follows the waves exactly: amplitude (0: none),
//   waves round a box, lobes of a cookie (0: a box), the cookie's turn (radians). Same maths as Frame.qml.
//   turn: a scene wallpaper's colour turn (Glass.shift, Glass.sat): the picture behind turns with the scene
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
    vec4 tune;
    vec4 wave;
    vec4 turn;
};
layout(binding = 1) uniform sampler2D source;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

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
    if (wave.x > 0.0) {
        float a = wave.x;
        if (wave.z > 0.0) {
            // a cookie: the radius swells `lobes` times round
            float R = min(size.x, size.y) * 0.5 - inset;
            float t = atan(q.y, q.x) - wave.w;
            sd = length(q) - (R - a + a * cos(wave.z * t));
            n = normalize(q + 1e-4);
        } else {
            // a wavy box: how far round the perimeter this is (clockwise from the top-left corner's end), and
            // the wave there pushes the edge out or in
            vec2 c = p - inset;
            float w = 2.0 * h.x, hh = 2.0 * h.y;
            float sx = w - 2.0 * r, sy = hh - 2.0 * r, arc = 1.5707963 * r;
            float P = 2.0 * sx + 2.0 * sy + 4.0 * arc;
            float s;
            if (c.x > w - r && c.y < r)
                s = sx + r * (atan(c.y - r, c.x - (w - r)) + 1.5707963);
            else if (c.x > w - r && c.y > hh - r)
                s = sx + arc + sy + r * atan(c.y - (hh - r), c.x - (w - r));
            else if (c.x < r && c.y > hh - r)
                s = 2.0 * sx + sy + 2.0 * arc + r * (atan(c.y - (hh - r), c.x - r) - 1.5707963);
            else if (c.x < r && c.y < r)
                s = 2.0 * sx + 2.0 * sy + 3.0 * arc + r * (atan(c.y - r, c.x - r) + 3.1415927);
            else {
                float dt = c.y, dr = w - c.x, db = hh - c.y, dl = c.x;
                float m = min(min(dt, dr), min(db, dl));
                s = m == dt ? c.x - r : m == dr ? sx + arc + c.y - r : m == db ? sx + sy + 2.0 * arc + (w - r - c.x) : 2.0 * sx + sy + 3.0 * arc + (hh - r - c.y);
            }
            sd -= a * sin(6.2831853 * wave.y * s / max(P, 1.0));
        }
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
    float bendK = tune.x, shine = tune.y;

    // the bevel: e is 1 at the very edge, 0 once past it. A convex rim's slope climbs steeply near the edge,
    // so what's behind is pulled in hard there and barely inside (and the middle magnifies a touch)
    float bezel = clamp(min(h.x, h.y) * 0.5, 6.0, 30.0);
    float e = clamp(1.0 - depth / bezel, 0.0, 1.0);
    float slope = e * e * e * (1.6 - 0.6 * e) + 0.35 * e * e;
    vec2 bend = -n * slope * bezel * 1.25 * bendK;

    vec2 origin = at.z > 0.5 ? at.xy : win.xy + inWin * win.zw - p;
    vec2 centre = origin + size * 0.5;
    vec2 here = origin + p;
    here = centre + (here - centre) * (1.0 - 0.03 * bendK);    // the slab magnifies a little
    vec2 s = here / screen;
    vec2 b = bend / screen;
    float fringe = 0.18 * bendK;
    vec3 col = vec3(texture(source, s + b * (1.0 + fringe)).r, texture(source, s + b).g, texture(source, s + b * (1.0 - fringe)).b);
    if (turn.x != 0.0 || turn.y != 1.0) {
        vec3 hsv = rgb2hsv(col);
        hsv.x = fract(hsv.x + turn.x);
        hsv.y = clamp(hsv.y * turn.y, 0.0, 1.0);
        col = hsv2rgb(hsv);
    }
    // livelier than the wallpaper, like light through glass
    float grey = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(grey), col, tune.z);
    col = mix(tint.rgb, col, back);

    // the tint over it, thinner over the bevel so the edge reads as thick clear glass
    col = mix(col, tint.rgb, tint.a * (1.0 - 0.45 * e * back));
    // the bevel catches a little more light than the flat middle
    col += vec3(0.05) * e * e * shine * back;

    // light on the rim: a crisp line all round, brightest where it faces the light (top-left) and on the far
    // side where the light comes back out (bottom-right), dimmest along the sides, plus a soft glow inside it
    vec2 L = normalize(vec2(-0.6, -0.8));
    float facing = dot(n, L);
    float line = smoothstep(1.8, 0.2, depth);
    float glow = smoothstep(bezel * 0.6, 0.0, depth);
    float spec = line * (0.16 + 0.85 * pow(max(facing, 0.0), 1.5) + 0.5 * pow(max(-facing, 0.0), 1.5))
        + glow * glow * (0.04 + 0.2 * pow(abs(facing), 2.0));
    col += mix(vec3(1.0), light.rgb, 0.2) * spec * shine;
    // a faint dark line just inside the rim, so it reads as an edge over bright backgrounds too
    col *= 1.0 - 0.18 * shine * smoothstep(1.2, 2.6, depth) * smoothstep(4.5, 2.6, depth) * edge;
    // and a sheen over the top
    col += vec3(0.04) * shine * pow(1.0 - uv.y, 3.0);

    float a = mix(tint.a, 1.0, back) * inside * qt_Opacity;
    fragColor = vec4(col * a, a);
}
