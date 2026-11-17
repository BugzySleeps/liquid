#version 440
// A still wallpaper brought to life (desktop/Wallpaper.qml, made by ~/.config/rice/livewall): the sea rolls and
// glitters, and the thing floating on it bobs and rocks on the swell, sinking into the water rather than over it.
//   plate:  the picture without the floating thing
//   figure: the floating thing alone
//   front:  black where the water is in front of the float
//   sun:    the sun alone (when there is one, hasSun): it rocks slowly, breathes, and glows
// With music playing it moves to it (energy, beat: from cava): the swell rises and quickens, the water glitters more,
// the float rides higher, and the sun pulses on the bass.
// Everything's worked out in the image's own pixels (q), then the picture is cropped to fill the screen like the
// still one is.
// Rebuild after editing:  qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o livewall.frag.qsb livewall.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // the screen, pixels
    vec2 img;           // the picture, pixels
    float time;         // seconds
    float flow;         // the sea's own clock: runs faster while the music's loud, so the waves quicken smoothly
    float energy;       // how loud, 0..1 (smoothed)
    float beat;         // the bass, 0..1 (quick to rise, quick to fall)
    float horizon;      // where the sea starts (image pixels)
    vec2 pivot;         // what the float rocks round (image pixels)
    vec4 sunAt;         // the sun: middle x, y, how far its rays reach (image pixels), 1 when there is one
};
layout(binding = 1) uniform sampler2D plate;
layout(binding = 2) uniform sampler2D figure;
layout(binding = 3) uniform sampler2D front;
layout(binding = 4) uniform sampler2D sun;

const float TAU = 6.2831853;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// how the water surface shifts what's seen through it here: bigger and slower towards the front, finer
// towards the horizon (perspective), with rings spreading from the float as it bobs
vec2 swell(vec2 q) {
    float d = clamp((q.y - horizon) / (img.y - horizon), 0.0, 1.0);
    float on = smoothstep(horizon + 1.0, horizon + 14.0, q.y);
    float k = 1.0 / (0.12 + d);                          // finer near the horizon
    float amp = (0.35 + 3.2 * d) * on * (1.0 + 1.3 * energy);
    float t = flow;
    vec2 o;
    o.x = sin(q.y * 0.11 * k + t * 1.1 + 2.0 * sin(q.x * 0.006 * k + t * 0.35)) * 0.7
        + sin(q.y * 0.23 * k - t * 1.7 + q.x * 0.004 * k) * 0.3;
    o.y = sin(q.x * 0.018 * k + t * 1.3 + q.y * 0.06 * k) * 0.6
        + sin(q.x * 0.041 * k - t * 2.1 + 1.7) * 0.4;
    // rings round the float, flattened by the angle we see the water at
    vec2 r = (q - (pivot + vec2(0.0, 40.0))) * vec2(1.0, 4.0);
    float rr = length(r);
    float ring = sin(rr * 0.045 - t * 1.6) * exp(-rr / 520.0) * smoothstep(300.0, 420.0, rr);
    o.y += ring * 1.4 * on;
    return o * amp;
}

void main() {
    // the screen pixel -> the picture's pixel, cropped to fill like the still one
    vec2 p = qt_TexCoord0 * size;
    float s = max(size.x / img.x, size.y / img.y);
    vec2 q = (p - (size - img * s) * 0.5) / s;

    // the sea and sky
    vec2 qs = q + (q.y > horizon ? swell(q) : vec2(0.0));
    vec3 col = texture(plate, qs / img).rgb;

    // the sun: a warm glow round it that swells and fades, then the sun itself, rocking a few degrees either way,
    // breathing a little bigger and back, and bobbing in the sky
    if (sunAt.w > 0.5 && q.y < horizon) {
        float breath = 0.5 + 0.5 * sin(time * 0.75);
        float kick = beat * beat;
        float reach = sunAt.z;
        vec2 c = sunAt.xy + vec2(0.0, 2.0 * sin(time * 0.5 + 1.0));
        float dist = length(q - c);
        col += vec3(1.0, 0.62, 0.3) * (0.10 + 0.08 * breath + 0.22 * kick) * exp(-max(0.0, dist - reach * 0.55) / (reach * 0.9));
        float a = 0.06 * sin(time * 0.4) + 0.02 * sin(time * 0.93 + 0.5);
        float k = 1.0 + 0.025 * breath + 0.05 * kick;
        vec2 rel = (q - c) / k;
        vec2 s = vec2(cos(a) * rel.x + sin(a) * rel.y, -sin(a) * rel.x + cos(a) * rel.y) + sunAt.xy;
        vec4 su = texture(sun, s / img);
        su.rgb *= 1.0 + 0.06 * breath + 0.12 * kick;
        col = su.rgb + col * (1.0 - su.a);            // (premultiplied)
    }

    if (q.y > horizon) {
        // glitter where the sun lights the water, twinkling
        float lum = dot(col, vec3(0.299, 0.587, 0.114));
        float tw = hash(floor(q / 1.6) + floor(time * 7.0) * 0.37);
        float glint = step(0.986 - 0.014 * energy, tw) * smoothstep(0.5, 0.85, lum);
        col += vec3(1.0, 0.93, 0.78) * glint * 0.75;
        // the swell's light: crests catch a little more of it
        col *= 1.0 + 0.05 * sin(q.y * 0.35 / (0.12 + (q.y - horizon) / (img.y - horizon)) + time * 1.4 + q.x * 0.01);
    }

    // the float, bobbing on the swell and rocking a touch
    float w = TAU / 4.6;
    float bob = (4.0 * sin(flow * w) + 1.4 * sin(flow * w * 1.9 + 1.3)) * (1.0 + 0.6 * energy);
    float sway = 1.6 * sin(flow * w * 0.55 + 0.4);
    float a = 0.008 * sin(time * w * 0.8 + 0.7) + 0.003 * sin(time * w * 1.7);
    vec2 rel = q - pivot - vec2(sway, bob);
    vec2 src = vec2(cos(a) * rel.x + sin(a) * rel.y, -sin(a) * rel.x + cos(a) * rel.y) + pivot;
    vec4 fig = texture(figure, src / img);
    // the water in front of it (rippling with the surface) covers whatever's sunk below
    float f = texture(front, qs / img).r;
    col = fig.rgb * f + col * (1.0 - fig.a * f);    // (the figure's colour comes premultiplied)

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
