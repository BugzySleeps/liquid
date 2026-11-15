#version 440
// The lock screen's liquid: a glowing pool filling the screen from the bottom. Its surface rolls with a
// few slow waves plus ripples (typing drops one at the login box); below it, the wallpaper is bent by
// the waves and tinted, with drifting caustics and rising bubbles. Above it, everything shows through.
// Rebuild after editing:  qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o liquid.frag.qsb liquid.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // pixels
    float time;         // seconds
    float level;        // 0 = empty, 1 = full (from the bottom)
    float rough;        // extra choppiness (filling, a wrong password)
    vec4 tint;          // the accent
    vec4 glow;          // the bright accent
    vec4 deep;          // the background
    vec4 r0; vec4 r1; vec4 r2; vec4 r3;   // ripples: x (pixels), start time, strength, unused
    vec4 r4; vec4 r5; vec4 r6; vec4 r7;
};

layout(binding = 1) uniform sampler2D source;  // what's behind (the blurred wallpaper)

float ripple(vec4 r, float x) {
    float age = time - r.y;
    if (r.z <= 0.0 || age < 0.0 || age > 4.0)
        return 0.0;
    float d = abs(x - r.x);
    float front = age * 420.0;                           // how far the ripple has spread
    float env = smoothstep(front, front - 160.0, d)      // only inside the spreading ring
              * exp(-age * 1.3) * exp(-d * 0.0022);
    return sin(d * 0.045 - age * 11.0) * 16.0 * r.z * env;
}

float surfaceY(float x) {
    float t = time;
    float h = sin(x * 0.0061 + t * 0.9) * 9.0
            + sin(x * 0.0123 - t * 1.4) * 5.0
            + sin(x * 0.0271 + t * 2.3) * 2.0;
    h *= 1.0 + rough * 2.5;
    h += ripple(r0, x) + ripple(r1, x) + ripple(r2, x) + ripple(r3, x)
       + ripple(r4, x) + ripple(r5, x) + ripple(r6, x) + ripple(r7, x);
    return size.y * (1.0 - level) + h;
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void main() {
    vec2 px = qt_TexCoord0 * size;
    float s = surfaceY(px.x);
    float below = px.y - s;                              // > 0 under the surface

    vec4 back = texture(source, qt_TexCoord0);
    if (below < -40.0 || level <= 0.0005) {
        fragColor = back * qt_Opacity;
        return;
    }

    // the surface's slope bends what's seen through it
    float slope = (surfaceY(px.x + 2.0) - surfaceY(px.x - 2.0)) * 0.25;
    float depth = clamp(below / max(size.y * level, 1.0), 0.0, 1.0);
    vec2 bend = vec2(slope * 0.02, 0.0)
              + vec2(sin(px.y * 0.03 + time * 1.7), cos(px.x * 0.025 + time * 1.3)) * 0.0035;
    vec3 seen = texture(source, clamp(qt_TexCoord0 + bend, 0.0, 1.0)).rgb;

    // the liquid: the accent over what's behind, deepening to the background at the bottom
    vec3 col = mix(seen * 0.55 + tint.rgb * 0.22, deep.rgb + tint.rgb * 0.05, smoothstep(0.0, 1.0, depth) * 0.85);

    // caustics: soft light bands drifting under the surface
    float c = sin(px.x * 0.018 + sin(px.y * 0.011 + time * 0.8) * 2.0 + time * 0.6)
            * sin(px.y * 0.021 - time * 0.9 + sin(px.x * 0.009) * 2.0);
    col += tint.rgb * pow(max(c, 0.0), 3.0) * 0.16 * (1.0 - depth);

    // bubbles: a few columns, each rising at its own pace
    for (int i = 0; i < 14; i++) {
        float fi = float(i);
        float bx = hash(fi * 7.13) * size.x + sin(time * 1.3 + fi) * 6.0;
        float speed = 30.0 + hash(fi * 3.7) * 60.0;
        float travel = size.y * level + 40.0;
        float by = size.y + 20.0 - mod(time * speed + hash(fi * 1.9) * travel, travel);
        float r = 1.5 + hash(fi * 5.3) * 2.5;
        float d = length(px - vec2(bx, by));
        float b = smoothstep(r, r - 1.2, d) * step(s + 6.0, by);
        col += glow.rgb * b * 0.5;
    }

    // the surface: a thin bright line with a glow either side
    float line = exp(-abs(below) * 0.55);
    float halo = exp(-abs(below) * 0.06) * 0.35;
    col += glow.rgb * line * 0.9 + tint.rgb * halo * 0.6;

    // above the surface only the halo shows, over what's behind
    float inside = smoothstep(-1.0, 1.0, below);
    vec3 outCol = mix(back.rgb + tint.rgb * halo * 0.5 * (1.0 - inside), col, inside);
    fragColor = vec4(outCol, 1.0) * qt_Opacity;
}
