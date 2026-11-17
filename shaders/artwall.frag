#version 440
// The album wallpaper's moving part (desktop/Wallpaper.qml), over the still backdrop rice makes from the cover
// (dark ground, glows, grain). One of four designs, in the cover's colours, stirred by the music (energy, from cava):
//   0 waves   three liquid waves along the bottom, light on each crest; louder music, higher swell
//   1 aurora  curtains of light hanging across the top, streaked, slowly rolling; brighter when it's loud
//   2 drips   liquid running down from the top edge in drips, drops falling off them
//   3 orb     a big glass bubble on the right, wobbling, a rim of light and a highlight, with a small one circling it
// Rebuild after editing:  qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o artwall.frag.qsb artwall.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // pixels
    float time;         // seconds
    float energy;       // 0..1, how loud (smoothed)
    float style;        // 0 waves · 1 aurora · 2 drips · 3 orb
    float seed;         // per cover, so each album's layout differs a little
    vec4 c0;            // the cover's colours, most used first
    vec4 c1;
    vec4 c2;
};

const float TAU = 6.2831853;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// paint `col` over `acc` (premultiplied) with coverage a
vec4 over(vec4 acc, vec3 col, float a) {
    return vec4(acc.rgb * (1.0 - a) + col * a, acc.a * (1.0 - a) + a);
}

vec4 waves(vec2 p) {
    vec4 acc = vec4(0.0);
    float W = size.x, H = size.y;
    for (int j = 0; j < 3; j++) {
        float fj = float(j);
        vec3 c = j == 0 ? c1.rgb : j == 1 ? c2.rgb : c0.rgb;
        float level = (0.66 + 0.10 * fj - 0.03 * energy) * H;
        float amp = (0.035 - 0.0065 * fj) * H * (1.0 + 1.4 * energy);
        float n = 1.3 + 0.65 * fj;
        float ph = seed * (3.0 + fj) + fj * 1.7;
        float t = p.x / W;
        float sp = time * (0.10 + 0.05 * fj) * (1.0 + 1.5 * energy);
        float ys = level + amp * (sin(TAU * n * t + ph + sp) + 0.35 * sin(TAU * n * 2.3 * t + ph * 1.9 - sp * 1.6));
        float d = p.y - ys;
        float inside = smoothstep(-1.0, 1.0, d);
        float depth = clamp(d / max(1.0, H - ys), 0.0, 1.0);
        float light = 0.42 + 0.14 * fj;
        acc = over(acc, c * light * (1.0 - 0.75 * depth), inside * 0.94);
        float crest = 1.0 - smoothstep(0.4, 1.8, abs(d));
        acc.rgb += mix(c, vec3(1.0), 0.6) * crest * (0.45 + 0.4 * energy);
        acc.a = max(acc.a, crest * 0.8);
    }
    return acc;
}

vec4 aurora(vec2 p) {
    vec4 acc = vec4(0.0);
    float W = size.x, H = size.y;
    for (int j = 0; j < 3; j++) {
        float fj = float(j);
        vec3 c = j == 0 ? c0.rgb : j == 1 ? c1.rgb : c2.rgb;
        float x = p.x / W;
        float cy = (0.12 + 0.09 * fj) * H + 0.06 * H * sin(TAU * x * (0.9 + 0.35 * fj) + time * (0.12 + 0.04 * fj) + seed * 2.0 + fj * 2.1)
                 + 0.02 * H * sin(TAU * x * 3.1 - time * 0.21 + fj);
        float d = p.y - cy;
        float hang = smoothstep(-0.012 * H, 0.0, d) * exp(-pow(max(d, 0.0) / (0.17 * H), 1.3));
        float streak = 0.6 + 0.4 * sin(p.x * 0.05 + time * 0.5 + fj * 3.0 + 5.0 * sin(p.x * 0.004 + time * 0.13 + seed));
        streak *= 0.75 + 0.25 * sin(p.x * 0.13 - time * 0.9 + fj);
        float glow = hang * streak * (0.45 + 0.55 * energy);
        float edge = exp(-abs(d) / (0.004 * H)) * (0.35 + 0.4 * energy) * streak;
        acc.rgb += c * (glow * 0.75) + mix(c, vec3(1.0), 0.5) * edge * 0.5;
        acc.a = max(acc.a, clamp(glow * 0.75 + edge * 0.5, 0.0, 1.0));
    }
    return acc;
}

vec4 drips(vec2 p) {
    float W = size.x, H = size.y;
    // the liquid's lower edge: a shallow band, and drips hanging from it
    float edge = 0.05 * H + 0.008 * H * sin(p.x / W * TAU * 2.0 + time * 0.3 + seed);
    vec4 acc = vec4(0.0);
    float drop = 0.0;
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        float r = hash(vec2(fi, seed));
        float xi = (fi + 0.5 + (r - 0.5) * 0.6) / 9.0 * W;
        float wi = (0.010 + 0.012 * hash(vec2(seed, fi))) * W;
        float L = (0.04 + 0.11 * r) * H * (0.75 + 0.25 * sin(time * (0.25 + 0.2 * r) + fi * 1.3)) * (1.0 + 0.6 * energy);
        float dx = (p.x - xi) / wi;
        edge = max(edge, 0.05 * H + L * exp(-dx * dx));
        // a drop falling off it now and then
        float ph = fract(time * (0.05 + 0.04 * r) + r * 3.0);
        float dy = 0.05 * H + L + ph * ph * H * 1.1;
        float rad = wi * 0.42;
        float dd = length(p - vec2(xi, dy)) - rad;
        drop = max(drop, smoothstep(1.0, -1.0, dd) * (1.0 - smoothstep(0.75, 1.0, ph)));
    }
    float d = edge - p.y;                                // > 0 inside the liquid
    float inside = smoothstep(-1.0, 1.0, d);
    float depth = clamp(p.y / max(1.0, edge), 0.0, 1.0);
    vec3 body = mix(c1.rgb * 0.18, c0.rgb * 0.62, depth * depth);
    acc = over(acc, body, inside * 0.95);
    acc = over(acc, c0.rgb * 0.65, drop * 0.95);
    float rim = 1.0 - smoothstep(0.4, 1.8, abs(d));
    acc.rgb += mix(c0.rgb, vec3(1.0), 0.6) * rim * (0.45 + 0.4 * energy);
    acc.a = max(acc.a, rim * 0.8);
    return acc;
}

vec4 bubble(vec2 p, vec2 c, float R, vec3 col, vec3 col2) {
    vec2 q = p - c;
    float a = atan(q.y, q.x);
    float r = R * (1.0 + 0.016 * sin(3.0 * a + time * 0.5) + 0.010 * sin(5.0 * a - time * 0.4 + seed));
    float len = length(q);
    float d = len - r;
    vec4 acc = vec4(0.0);
    // a soft glow round it
    float halo = exp(-max(d, 0.0) / (0.35 * R)) * 0.35 * (1.0 - smoothstep(-1.0, 1.0, -d));
    acc.rgb += col * halo;
    acc.a = max(acc.a, halo);
    float inside = smoothstep(1.0, -1.0, d);
    float k = clamp(len / r, 0.0, 1.0);
    vec3 body = mix(col * 0.12, col2 * 0.5, clamp(q.y / r * 0.5 + 0.5, 0.0, 1.0));   // light pools at the bottom
    body += col * pow(k, 5.0) * 0.55;                    // the rim, brighter at the edge
    acc = over(acc, body, inside * 0.82);
    vec2 hp = (q - vec2(-0.32, -0.45) * r) / (vec2(0.36, 0.16) * r);
    acc.rgb += vec3(1.0) * exp(-dot(hp, hp) * 2.0) * 0.32 * inside;
    float line = 1.0 - smoothstep(0.4, 1.8, abs(d));
    acc.rgb += mix(col, vec3(1.0), 0.6) * line * 0.6;
    acc.a = max(acc.a, line * 0.8);
    return acc;
}

vec4 orb(vec2 p) {
    float W = size.x, H = size.y;
    float R = 0.27 * H * (1.0 + 0.05 * energy) + 0.005 * H * sin(time * 0.7);
    vec2 c = vec2(0.80 * W, 0.44 * H);
    vec4 acc = bubble(p, c, R, c0.rgb, c1.rgb);
    float a = time * 0.09 + seed;
    vec2 m = c + vec2(cos(a), sin(a) * 0.55) * R * 1.55;
    vec4 small = bubble(p, m, 0.055 * H * (1.0 + 0.15 * energy), c2.rgb, c0.rgb);
    return vec4(acc.rgb * (1.0 - small.a) + small.rgb, acc.a * (1.0 - small.a) + small.a);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec4 col = style < 0.5 ? waves(p) : style < 1.5 ? aurora(p) : style < 2.5 ? drips(p) : orb(p);
    col = clamp(col, 0.0, 1.0);
    // grain over the whole screen (the backdrop under this is soft and small): lighter specks added, darker
    // ones as a little black over it
    float g = (hash(floor(p) + floor(fract(time * 0.5) * 8.0)) - 0.5) * 0.09;
    col = g > 0.0 ? vec4(col.rgb + g, col.a) : over(col, vec3(0.0), -g);
    fragColor = col * qt_Opacity;
}
