.pragma library

// Widget shapes (round and squiggle only; square keeps every box square). Every shape is a list of `N`
// distances along `N` rays from the middle, each ray stretched to the box (1 = the box's edge), so any two
// shapes morph by mixing their lists. "box" and "pill" are worked out in pixels (their corners stay round on
// any size); the rest are drawn round a circle and want a square box.

var N = 240;

// [name, label] in the order the picker shows them
var list = [
    ["box", "box"], ["pill", "pill"], ["circle", "circle"], ["squircle", "squircle"], ["arch", "arch"],
    ["gem", "gem"], ["diamond", "diamond"], ["triangle", "triangle"], ["pentagon", "pentagon"],
    ["cookie4", "4-cookie"], ["cookie6", "6-cookie"], ["cookie9", "9-cookie"], ["cookie12", "12-cookie"],
    ["clover4", "4-clover"], ["clover8", "8-clover"], ["flower", "flower"], ["puffy", "puffy"],
    ["sunny", "sunny"], ["burst", "burst"]
];

// the ones that keep any proportions; the others square their widget up
function free(name) {
    return name === "box" || name === "pill" || !name;
}

function angle(i) {
    return i / N * 2 * Math.PI - Math.PI / 2;    // starting at the top, clockwise
}

// a radius list, smoothed round the circle over `k` samples either side (soft corners)
function soften(r, k) {
    if (k < 1)
        return r;
    var out = [];
    for (var i = 0; i < N; i++) {
        var s = 0, wsum = 0;
        for (var j = -k; j <= k; j++) {
            var w = 1 - Math.abs(j) / (k + 1);
            s += r[(i + j + N) % N] * w;
            wsum += w;
        }
        out.push(s / wsum);
    }
    return out;
}

function polar(f, k) {
    var r = [];
    for (var i = 0; i < N; i++)
        r.push(f(angle(i)));
    r = soften(r, k || 0);
    var m = 0;
    for (var i2 = 0; i2 < N; i2++)
        m = Math.max(m, r[i2]);
    return r.map(function (v) { return v / m; });
}

// a regular polygon (n sides, a point at the top), as a radius at each angle
function polygon(n, t) {
    var seg = 2 * Math.PI / n;
    var a = ((t + Math.PI / 2) % seg + seg) % seg - seg / 2;
    return Math.cos(Math.PI / n) / Math.cos(a);
}

// a rounded box w × h with corner radius rad, by walking each ray out to its edge (a signed distance)
function boxRays(w, h, rad) {
    var out = [], bx = w / 2, by = h / 2;
    rad = Math.max(0, Math.min(rad, bx, by));
    for (var i = 0; i < N; i++) {
        var t = angle(i), dx = Math.cos(t) * bx, dy = Math.sin(t) * by;
        var lo = 0, hi = 1.6;
        for (var it = 0; it < 22; it++) {
            var s = (lo + hi) / 2;
            var qx = Math.abs(dx * s) - (bx - rad), qy = Math.abs(dy * s) - (by - rad);
            var d = Math.sqrt(Math.pow(Math.max(qx, 0), 2) + Math.pow(Math.max(qy, 0), 2)) + Math.min(Math.max(qx, qy), 0) - rad;
            if (d <= 0)
                lo = s;
            else
                hi = s;
        }
        out.push(lo);
    }
    return out;
}

var cache = {};
function rays(name, w, h, boxRadius) {
    if (name === "box" || !name)
        return boxRays(w, h, boxRadius);
    if (name === "pill")
        return boxRays(w, h, Math.min(w, h) / 2);
    if (cache[name])
        return cache[name];
    var P = Math.PI, r;
    switch (name) {
    case "circle":
        r = polar(function (t) { return 1; });
        break;
    case "squircle":
        r = polar(function (t) { return Math.pow(Math.pow(Math.abs(Math.cos(t)), 4) + Math.pow(Math.abs(Math.sin(t)), 4), -0.25); });
        break;
    case "arch":                                 // a half circle on top, a soft-cornered square below
        r = polar(function (t) { return Math.sin(t) < 0 ? 1 : Math.min(1 / Math.max(Math.abs(Math.cos(t)), 1e-6), 1 / Math.max(Math.sin(t), 1e-6)); }, 9);
        break;
    case "gem":                                  // a tall hexagon
        r = polar(function (t) { return polygon(6, t + P / 6) * (1 - 0.12 * Math.pow(Math.cos(t), 2)); }, 7);
        break;
    case "diamond":
        r = polar(function (t) { return polygon(4, t); }, 10);
        break;
    case "triangle":
        r = polar(function (t) { return polygon(3, t); }, 14);
        break;
    case "pentagon":
        r = polar(function (t) { return polygon(5, t); }, 9);
        break;
    case "cookie4":
        r = polar(function (t) { return 1 + 0.1 * Math.cos(4 * t); }, 2);
        break;
    case "cookie6":
        r = polar(function (t) { return 1 + 0.075 * Math.cos(6 * t); }, 2);
        break;
    case "cookie9":
        r = polar(function (t) { return 1 + 0.06 * Math.cos(9 * t); }, 1);
        break;
    case "cookie12":
        r = polar(function (t) { return 1 + 0.045 * Math.cos(12 * t); }, 1);
        break;
    case "clover4":                              // four round leaves, pinched where they meet
        r = polar(function (t) { return 0.62 + 0.38 * Math.pow(Math.abs(Math.cos(2 * t)), 0.55); }, 4);
        break;
    case "clover8":
        r = polar(function (t) { return 0.78 + 0.22 * Math.pow(Math.abs(Math.cos(4 * t)), 0.6); }, 3);
        break;
    case "flower":                               // eight soft petals
        r = polar(function (t) { return 0.8 + 0.2 * Math.pow(0.5 + 0.5 * Math.cos(8 * t), 0.7); }, 2);
        break;
    case "puffy":                                // a cloud: big round lobes with tight dips
        r = polar(function (t) { return 0.84 + 0.16 * Math.abs(Math.sin(3 * t + P / 2)); }, 3);
        break;
    case "sunny":                                // eight gentle points
        r = polar(function (t) { return 0.9 + 0.1 * (1 - Math.abs(((4 * t / P) % 1 + 1) % 1 * 2 - 1)); }, 3);
        break;
    case "burst":                                // twelve sharp points
        r = polar(function (t) { return 0.8 + 0.2 * (1 - Math.abs(((6 * t / P) % 1 + 1) % 1 * 2 - 1)); }, 2);
        break;
    default:
        return boxRays(w, h, boxRadius);
    }
    cache[name] = r;
    return r;
}

// where the content goes: the biggest centred box inside the shape whose height is `q` × its width (in the
// shape's own stretched space), as [width, height], each 0–1 of the shape's
function inner(r, q) {
    q = q || 1;
    var a = 1;
    for (var i = 0; i < N; i++) {
        var t = angle(i), c = Math.abs(Math.cos(t)), s = Math.abs(Math.sin(t));
        // the box's edge along this ray is at a × min(1/c, q/s): it has to stay inside the shape
        a = Math.min(a, r[i] / Math.min(c > 1e-6 ? 1 / c : 1e9, s > 1e-6 ? q / s : 1e9));
    }
    return [a, Math.min(1, a * q)];
}

// the outline as points: rays `r` (turned by `turn`, 0–1 of a full turn) in a w × h box, shrunk by `inset` px
function points(r, w, h, turn, inset) {
    var pts = [], cx = w / 2, cy = h / 2, sh = Math.round((turn || 0) * N);
    var ax = Math.max(0, w / 2 - (inset || 0)), ay = Math.max(0, h / 2 - (inset || 0));
    for (var i = 0; i <= N; i++) {
        var t = angle(i % N), v = r[((i - sh) % N + N) % N];
        pts.push(Qt.point(cx + Math.cos(t) * v * ax, cy + Math.sin(t) * v * ay));
    }
    return pts;
}

function mix(a, b, f) {
    var out = [];
    for (var i = 0; i < N; i++)
        out.push(a[i] + (b[i] - a[i]) * f);
    return out;
}
