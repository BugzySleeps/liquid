#!/usr/bin/env python3
"""Synthesises the shell's sounds (soft, short, watery) into this folder: python3 make.py
   drip.wav    a notification: a drop of water, and a smaller one after it
   bubble.wav  unlocking: three bubbles rising
   click.wav   a screenshot: a soft shutter
   tick.wav    volume / brightness: a tiny tick
   term-<style>-open.wav / term-<style>-close.wav   a terminal opening / closing, in four styles:
       ps2     the cold console menu: a reverse swell into a deep boom, glass and a whoosh / sliding down, "thoom"
       hud     a cyberpunk HUD: an FM zap up and two robotic beeps / the zap down into a low beep
       crt     an old monitor: thunk, static and a rising whine / the "zwip" collapse, crackle, a pip
       glitch  a gated, stuttering digital buzz bwooping up / falling and breaking up
   lock-*.wav  the lock screen's liquid, timed to its animations: fill (locking), intro (the first lock of a
               session), drain (unlocking), drop-1…4 / undrop (typing, deleting), splash (a wrong password)
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
HERE = Path(__file__).parent


def drop(t0, f0, f1, glide, tau, amp):
    """A water drop: a sine whose pitch rises fast (the bubble resonance), decaying."""
    def s(t):
        t -= t0
        if t < 0:
            return 0.0
        f = f1 - (f1 - f0) * math.exp(-t / glide)
        phase = 2 * math.pi * (f1 * t - (f1 - f0) * glide * (1 - math.exp(-t / glide)))
        attack = min(1.0, t / 0.002)
        return amp * attack * math.exp(-t / tau) * math.sin(phase)
    return s


def write(name, length, parts, normalise=True):
    n = int(RATE * length)
    data = [sum(p(i / RATE) for p in parts) for i in range(n)]
    if normalise:
        peak = max(abs(x) for x in data) or 1
        data = [x / peak * 0.55 for x in data]
    fade = int(RATE * 0.01)                      # no click at the end
    for i in range(fade):
        data[-1 - i] *= i / fade
    with wave.open(str(HERE / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in data))


random.seed(7)
write("drip.wav", 0.32, [drop(0.0, 520, 1350, 0.012, 0.055, 1.0), drop(0.11, 760, 1700, 0.009, 0.04, 0.45)])
write("bubble.wav", 0.42, [drop(0.0, 420, 900, 0.02, 0.06, 0.8), drop(0.08, 520, 1150, 0.016, 0.05, 0.7),
                           drop(0.17, 640, 1450, 0.013, 0.05, 0.6)])
noise = [random.uniform(-1, 1) for _ in range(RATE)]
def shutter(t):
    i = int(t * RATE)
    burst = noise[i % RATE] * math.exp(-t / 0.006) * 0.6
    thump = math.sin(2 * math.pi * 140 * t) * math.exp(-t / 0.012)
    second = noise[(i * 3) % RATE] * math.exp(-max(0, t - 0.07) / 0.005) * 0.35 if t > 0.07 else 0
    return burst + thump + second
write("click.wav", 0.14, [shutter])
write("tick.wav", 0.05, [lambda t: math.sin(2 * math.pi * 1900 * t) * math.exp(-t / 0.006) * 0.5])


# ── the terminal sounds: four cyber styles, each an open + a close (Settings.termStyle picks one).
#    Short, digital, punchy, and mid-heavy so they carry on a laptop speaker. ──
def render(length, parts):
    return [sum(p(i / RATE) for p in parts) for i in range(int(RATE * length))]


def square(t0, f0, f1, length, amp, duty=0.5, decay=None):
    """A square wave gliding f0 -> f1 (duty < 0.5 is thinner and more nasal: the 8-bit sound)."""
    def s(t):
        t -= t0
        if t < 0 or t > length:
            return 0.0
        k = t / length
        ph = f0 * length * ((f1 / f0) ** k - 1) / math.log(f1 / f0) if f1 != f0 else f0 * t
        env = min(1.0, t / 0.001) * min(1.0, (length - t) / 0.002) * (math.exp(-t / decay) if decay else 1)
        return amp * env * (1 if ph % 1 < duty else -1)
    return s


def sine(t0, f0, f1, length, amp, decay=None):
    def s(t):
        t -= t0
        if t < 0 or t > length:
            return 0.0
        k = t / length
        ph = f0 * length * ((f1 / f0) ** k - 1) / math.log(f1 / f0) if f1 != f0 else f0 * t
        env = min(1.0, t / 0.001) * min(1.0, (length - t) / 0.002) * (math.exp(-t / decay) if decay else 1)
        return amp * env * math.sin(2 * math.pi * ph)
    return s


def zap(t0, f0, f1, length, amp, ratio=1.41, index=4.0):
    """An FM zap: a carrier sweeping f0 -> f1, modulated hard at first (metallic), cleaner by the end."""
    def s(t):
        t -= t0
        if t < 0 or t > length:
            return 0.0
        k = t / length
        ph = f0 * length * ((f1 / f0) ** k - 1) / math.log(f1 / f0)
        f = f0 * (f1 / f0) ** k
        mod = index * (1 - k) ** 2 * math.sin(2 * math.pi * f * ratio * t)
        env = min(1.0, t / 0.001) * (1 - k) ** 0.6
        return amp * env * math.sin(2 * math.pi * ph + mod)
    return s


def static(t0, length, amp, decay, tone=0.5, crackle=0.0):
    """Static: noise, brighter or darker (`tone`), decaying; `crackle` turns it into sparse pops."""
    state = {"lp": 0.0}
    def s(t):
        t -= t0
        if t < 0 or t > length:
            return 0.0
        i = int(t * RATE)
        n = noise[(i * 7 + 13) % RATE]
        state["lp"] += (1 - tone) * (n - state["lp"])
        v = n - state["lp"] if tone > 0.5 else state["lp"]
        if crackle and abs(noise[(i // 40 * 31) % RATE]) < 1 - crackle:
            v *= 0.05
        return amp * v * math.exp(-t / decay)
    return s


def ring(x, f, depth=1.0):
    """Ring modulation: multiplied by a sine, the robot voice."""
    return [v * (1 - depth + depth * math.sin(2 * math.pi * f * i / RATE)) for i, v in enumerate(x)]


def echo(x, delay, gain, repeats=2):
    d = int(delay * RATE)
    out = x + [0.0] * (d * repeats)
    for r in range(1, repeats + 1):
        g = gain ** r
        for i, v in enumerate(x):
            out[i + d * r] += v * g
    return out


def lofi(x, hold, bits, top=9000):
    """Digital grit: a lower sample rate and fewer bits, then a low-pass to take the fizz off."""
    levels, held = 2 ** (bits - 1), 0.0
    peak = max(abs(v) for v in x) or 1
    lp = [0.0, 0.0, 0.0]                         # three one-pole stages: stable at any `top`
    a = 1 - math.exp(-2 * math.pi * top / RATE)
    out = []
    for i, v in enumerate(x):
        if i % hold == 0:
            held = round(v / peak * levels) / levels * peak
        y = held
        for j in range(3):
            lp[j] += a * (y - lp[j])
            y = lp[j]
        out.append(y)
    return out


def buzz(length, f0, f1, cut0, cut1, gate, stutter_end, retrig, res=0.18, top=1900):
    """A gated, stuttering digital buzz: a chord of square waves (root, fifth, sub-octave) through a
    resonant low-pass sweeping cut0 -> cut1, chopped at `gate` Hz until `stutter_end`, a dropout at `retrig`."""
    n = int(RATE * length)
    out, low, band, ph, gph = [], 0.0, 0.0, [0.0, 0.0, 0.0], 0.0
    lp = [[0.0, 0.0] for _ in range(4)]
    tq = 2 * math.sin(math.pi * top / RATE)
    for i in range(n):
        t = i / RATE
        k = t / length
        f = f0 * (f1 / f0) ** min(1, k * 1.6)
        x = 0.0
        for j, mul in enumerate((1.0, 1.5, 0.5)):
            ph[j] = (ph[j] + f * mul / RATE) % 1
            x += (1 if ph[j] < 0.5 else -1) * (0.5 if j == 2 else 0.38)
        fq = 2 * math.sin(math.pi * min(cut0 * (cut1 / cut0) ** k, RATE / 7) / RATE)
        low += fq * band
        band += fq * (x - low - res * 2 * band)
        y = math.tanh(low * 1.6)
        gph = (gph + (gate[0] + (gate[1] - gate[0]) * k) / RATE) % 1
        if t < stutter_end and gph > 0.62:
            y *= 0.08
        if retrig and retrig <= t < retrig + 0.009:
            y *= 0.05
        y *= min(1.0, t / 0.002) * min(1.0, (length - t) / 0.004)
        for st in lp:
            st[0] += tq * st[1]
            st[1] += tq * (y - st[0] - 1.41 * st[1])
            y = st[0]
        out.append(y)
    return out


def reverb(x, mix, size=1.0, tail=0.8, damp=0.45):
    """A hall (Freeverb's layout: eight damped combs, four all-passes), added after the dry sound."""
    combs = [int(d * 48 / 44.1 * size) for d in (1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617)]
    n = len(x) + int(RATE * tail)
    dry = x + [0.0] * (n - len(x))
    wet = [0.0] * n
    for d in combs:
        buf, lp, k = [0.0] * d, 0.0, 0
        for i in range(n):
            y = buf[k]
            lp = y * (1 - damp) + lp * damp      # damping: the tail darkens as it fades
            buf[k] = dry[i] * 0.12 + lp * 0.84
            wet[i] += y
            k = (k + 1) % d
    for d in (556, 441, 341, 225):
        d = int(d * 48 / 44.1)
        buf, k = [0.0] * d, 0
        for i in range(n):
            b = buf[k]
            buf[k] = wet[i] + b * 0.5
            wet[i] = b - wet[i]
            k = (k + 1) % d
    return [a * (1 - mix) + b * mix for a, b in zip(dry, wet)]


def whoosh(length, f0, f1, amp, q=0.25, attack=0.08):
    """Air through a resonant band-pass sweeping f0 -> f1: the "shwoooom"."""
    out, low, band = [], 0.0, 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        k = t / length
        fc = f0 * (f1 / f0) ** k
        fq = 2 * math.sin(math.pi * min(fc, RATE / 7) / RATE)
        x = noise[(i * 5 + 7) % RATE]
        low += fq * band
        band += fq * (x - low - q * band)
        env = min(1.0, t / attack) * (1 - k) ** 1.2
        out.append(amp * band * env)
    return out


def glass(t0, freqs, amp, attack, decay, glide=1.0, length=None):
    """A cold glass chord: each note two sines a few cents apart, so it glistens; `glide` bends it
    (0.5 = down an octave over its length)."""
    def s(t):
        t -= t0
        if t < 0 or (length and t > length):
            return 0.0
        bend = glide ** (t / length) if length else 1
        env = min(1.0, t / attack) * math.exp(-t / decay)
        v = 0.0
        for f in freqs:
            v += math.sin(2 * math.pi * f * bend * t) + math.sin(2 * math.pi * f * 1.004 * bend * t + 1)
        return amp * env * v / (2 * len(freqs))
    return s


def boom(t0, f0, f1, amp, decay):
    """A soft deep boom, pitch falling f0 -> f1, a touch of saturation so a small speaker still hears it."""
    def s(t):
        t -= t0
        if t < 0:
            return 0.0
        f = f1 + (f0 - f1) * math.exp(-t / 0.08)
        ph = 2 * math.pi * (f1 * t + (f0 - f1) * 0.08 * (1 - math.exp(-t / 0.08)))
        return amp * math.tanh(2.2 * math.sin(ph)) * min(1.0, t / 0.012) * math.exp(-t / decay)
    return s


def grains(t0, length, amp, density=180):
    """Cyber data texture: tiny 3 ms grains of bright ringing noise at random moments."""
    rnd = random.Random(int(t0 * 1000) + density)
    hits = sorted(t0 + rnd.random() * length for _ in range(int(density * length)))
    pitches = [rnd.choice((2600, 3100, 3700, 4400)) for _ in hits]
    def s(t):
        v = 0.0
        for h, f in zip(hits, pitches):
            d = t - h
            if 0 <= d < 0.003:
                v += math.sin(2 * math.pi * f * d) * (1 - d / 0.003)
        return amp * v
    return s


def save(name, data, loudness=0.17):
    """Evened out by average loudness (not peak), so the styles sit at the same volume; a soft limiter
    keeps the peaks from clipping."""
    rms = (sum(v * v for v in data) / len(data)) ** 0.5 or 1
    data = [0.92 * math.tanh(v * loudness / rms / 0.92) for v in data]
    write(name, len(data) / RATE, [lambda t, d=data: d[min(len(d) - 1, round(t * RATE))]], normalise=False)


# ps2: the cold, dark console menu. Open: a reverse-reverb swell breathes in, landing on a deep boom, a
# glass chord and a rising whoosh, with a grain of data texture; the hall trails off. Close: the glass slides
# down in a falling whoosh, the boom drops ("thoom"), and it fades into the dark.
chord = [587.33, 880.0, 1174.66, 1760.0]                       # D5 A5 D6 A6: open fifths, cold
hit = render(0.5, [glass(0.0, chord, 0.6, 0.004, 0.18)])
swell = reverb(hit, 1.0, 1.1, 0.4, damp=0.3)[::-1]             # reversed: it breathes in
swell = swell[-int(RATE * 0.32):]
n = len(swell)
hp, prev = 0.0, 0.0
for i in range(n):                                             # out of silence (the curve), no rumble under it
    hp = 0.98 * (hp + swell[i] - prev)
    prev = swell[i]
    swell[i] = hp * (i / n) ** 2.2
body = render(0.7, [
    boom(0.0, 110, 46, 0.9, 0.22),
    glass(0.0, chord, 0.55, 0.01, 0.35),
    glass(0.0, [chord[-1] * 2], 0.12, 0.03, 0.2),              # a sparkle on top
    grains(0.02, 0.16, 0.09),
])
air = whoosh(0.45, 300, 3600, 0.5, attack=0.03)
body = [v + (air[i] if i < len(air) else 0) for i, v in enumerate(body)]
save("term-ps2-open.wav", lofi(reverb(swell + body, 0.42, 1.1, 0.5), 1, 14, 6500))

body = render(0.55, [
    glass(0.0, chord, 0.55, 0.004, 0.25, glide=0.5, length=0.55),
    boom(0.06, 92, 38, 0.85, 0.25),
    grains(0.0, 0.08, 0.07),
])
air = whoosh(0.4, 3400, 250, 0.45, attack=0.01)
body = [v + (air[i] if i < len(air) else 0) for i, v in enumerate(body)]
save("term-ps2-close.wav", lofi(reverb(body, 0.4, 1.1, 0.6), 1, 14, 6000))

# hud: a cyberpunk HUD. An FM zap sweeping up, then two robotic confirm beeps; closing, the zap sweeps
# down into one low beep.
save("term-hud-open.wav", lofi(ring(render(0.24, [
    zap(0.0, 280, 1900, 0.12, 0.7),
    sine(0.13, 2093, 2093, 0.028, 0.45), sine(0.175, 2637, 2637, 0.04, 0.45, decay=0.03),
    static(0.0, 0.008, 0.5, 0.002, tone=0.9),
]), 160, 0.55), 2, 10))
save("term-hud-close.wav", lofi(ring(render(0.26, [
    zap(0.0, 2000, 160, 0.16, 0.7, index=5.0),
    sine(0.17, 523.25, 523.25, 0.07, 0.5, decay=0.035),
    static(0.0, 0.008, 0.5, 0.002, tone=0.9),
]), 95, 0.5), 2, 10))

# crt: an old monitor. Power on: a thunk, a burst of static, a high whine rising in. Power off: the
# "zwip" collapse, a crackle, a last pip.
save("term-crt-open.wav", lofi(render(0.3, [
    sine(0.0, 90, 55, 0.08, 0.8, decay=0.03), static(0.0, 0.006, 0.6, 0.002, tone=0.9),
    static(0.01, 0.18, 0.45, 0.06, tone=0.75),
    lambda t: 0.09 * min(1, t / 0.1) * max(0, 1 - t / 0.3) * math.sin(2 * math.pi * (5200 * t + 600 * t * t)),
]), 2, 9, 11000))
save("term-crt-close.wav", lofi(render(0.24, [
    sine(0.0, 3400, 70, 0.1, 0.75),
    static(0.08, 0.12, 0.4, 0.05, tone=0.75, crackle=0.85),
    sine(0.2, 1200, 1200, 0.016, 0.3),
]), 2, 9, 11000))

# glitch: a gated, stuttering digital buzz. Open bwoops up with a double hit; close falls, breaking up.
save("term-glitch-open.wav", buzz(0.32, 98, 147, 260, 2300, (30, 30), 0.11, 0.165))
save("term-glitch-close.wav", buzz(0.34, 165, 78, 2400, 210, (22, 48), 0.34, 0.0, 0.14))

# ── the lock screen's liquid (lock/LockView.qml): each sound follows its animation's timing and easing, so
#    you hear what you see. Real water is mostly tiny bubbles, each a sine chirping up as it forms (drop()), so
#    the liquid here is a stream of them, thicker the faster it moves, over a band of rushing noise. ──
def speed(ease, k, e=1e-3):
    """How fast an eased animation is moving at k (0…1), 0 outside it."""
    if k <= 0 or k >= 1:
        return 0.0
    return (ease(min(1, k + e)) - ease(max(0, k - e))) / (min(1, k + e) - max(0, k - e))


def out_cubic(k):
    return 1 - (1 - k) ** 3


def in_cubic(k):
    return k ** 3


def in_out_cubic(k):
    return 4 * k ** 3 if k < 0.5 else 1 - (-2 * k + 2) ** 3 / 2


def span(t, start, length):
    return max(0.0, min(1.0, (t - start) / length))


def bubbles(length, rate, pitch, amp, seed, big=1.0):
    """rate(t) bubbles a second, around pitch(t) Hz, each about amp(t) loud. Bigger bubbles ring lower
    and longer (`big` makes them all bigger)."""
    rnd = random.Random(seed)
    out = [0.0] * int(RATE * length)
    top = max(rate(i / 200) for i in range(int(length * 200) + 1)) or 1
    t = 0.0
    while True:
        t += rnd.expovariate(top)
        if t >= length:
            break
        if rnd.random() > rate(t) / top:
            continue
        f0 = pitch(t) * rnd.uniform(0.72, 1.35)
        tau = min(0.09, 0.028 * big * 700 / f0) * rnd.uniform(0.7, 1.3)
        d = drop(t, f0, f0 * rnd.uniform(1.5, 2.3), rnd.uniform(0.006, 0.014), tau, amp(t) * rnd.uniform(0.25, 1.0))
        i0 = int(t * RATE)
        for i in range(i0, min(len(out), i0 + int(tau * 7 * RATE))):
            out[i] += d(i / RATE)
    return out


def rush(length, fc, env, q=0.6, wobble=9.0, seed=5):
    """The water's body: noise through a band-pass at fc(t) Hz, env(t) loud, its level wobbling a few
    times a second like moving water."""
    rnd = random.Random(seed)
    out, low, band, w, wt = [], 0.0, 0.0, 0.5, 0.5
    a = 1 - math.exp(-2 * math.pi * wobble / RATE)
    for i in range(int(RATE * length)):
        t = i / RATE
        if i % 600 == 0:
            wt = rnd.random()
        w += a * (wt - w)
        fq = 2 * math.sin(math.pi * min(fc(t), RATE / 7) / RATE)
        low += fq * band
        band += fq * (noise[(i * 11 + 3) % RATE] - low - q * band)
        out.append(band * env(t) * (0.45 + 0.9 * w))
    return out


def mix(*tracks):
    n = max(len(x) for x in tracks)
    return [sum(x[i] for x in tracks if i < len(x)) for i in range(n)]


# fill: locking. The level rises over 1.7 s (OutCubic: fastest at once, slowing as it settles) and the chop
# calms over 2.6 s (OutQuad). A pour that thins out and rises in pitch as the pool fills, a soft whumpf as it
# starts, and the console glass coming in faintly with the clock and the box (0.35 s on).
spd = lambda t: speed(out_cubic, t / 1.7)
chop = lambda t: (1 - span(t, 0, 2.6)) ** 2
filled = lambda t: out_cubic(span(t, 0, 1.7))
save("lock-fill.wav", reverb(mix(
    bubbles(2.9, lambda t: 12 + 240 * spd(t) + 30 * chop(t), lambda t: 480 + 620 * filled(t),
            lambda t: 0.25 + 0.5 * spd(t) + 0.2 * chop(t), seed=11),
    rush(2.9, lambda t: 650 + 900 * filled(t), lambda t: min(1, t / 0.04) * (0.55 * spd(t) + 0.07 * chop(t))),
    render(2.9, [boom(0.0, 150, 70, 0.35, 0.12), glass(0.35, chord, 0.1, 0.45, 0.7)]),
), 0.25, 0.8, 0.5))

# intro: the first lock of a session. The logo glows on the black (0–0.7 s: the glass swells in), its drop
# lands with a plop at 0.7 s (components/Logo.qml), the liquid
# rises over it (0.7–2.3 s, InOutCubic: a surge, the pitch climbing as it fills the screen), the screen full
# for a moment (2.3–2.65 s: under water, a deep muffled boom and a few slow bubbles), then it drains to rest
# (2.65–4.05 s: the pitch falling, big glugs at its fastest) as the clock and the glass come back in.
rise = lambda t: speed(in_out_cubic, (t - 0.7) / 1.6)
down = lambda t: speed(in_out_cubic, (t - 2.65) / 1.4)
under = lambda t: 1.0 if 2.3 <= t < 2.65 else 0.0
chop = lambda t: (0.35 + 0.65 * (1 - span(t, 0.7, 1.6))) * (t < 2.65) + 0.35 * (1 - span(t, 2.65, 1.8)) ** 2 * (t >= 2.65)
pitch = lambda t: 260 if under(t) else (420 + 900 * in_out_cubic(span(t, 0.7, 1.6)) if t < 2.3 else
                                        1250 - 800 * in_out_cubic(span(t, 2.65, 1.4)))
rnd = random.Random(21)
glugs = [drop(2.65 + 1.4 * k + rnd.uniform(-0.02, 0.02), 170 + 60 * rnd.random(), 330, 0.02, 0.07, 0.5)
         for k in (0.3, 0.38, 0.45, 0.52, 0.6, 0.69)]
save("lock-intro.wav", reverb(mix(
    bubbles(4.6, lambda t: 6 + 230 * rise(t) + 170 * down(t) + 25 * chop(t) + 14 * under(t), pitch,
            lambda t: 0.2 + 0.5 * (rise(t) + down(t)) + 0.15 * chop(t), seed=12),
    rush(4.6, lambda t: 500 + 1100 * in_out_cubic(span(t, 0.7, 1.6)) - 900 * in_out_cubic(span(t, 2.65, 1.4)),
         lambda t: 0.5 * (rise(t) + down(t)) + 0.05 * chop(t)),
    render(4.6, [glass(0.0, chord, 0.22, 0.6, 1.0), boom(0.0, 70, 45, 0.2, 0.5),
                 drop(0.7, 280, 640, 0.02, 0.1, 0.8), drop(0.74, 420, 980, 0.012, 0.05, 0.3),   # the logo's drop lands
                 boom(2.3, 90, 42, 0.6, 0.3), glass(3.25, chord, 0.14, 0.5, 0.8)] + glugs),
), 0.3, 1.0, 0.6))

_slurp = whoosh(0.16, 2600, 500, 1.0, q=0.4, attack=0.06)
def whoosh_at(t, at=1.24):
    i = round((t - at) * RATE)
    return _slurp[i] if 0 <= i < len(_slurp) else 0.0


# drain: unlocking. A moment of "welcome back" (0.38 s: bubbles rising with the glass), then the pool drains
# (0.95 s, InCubic: slow, then faster and faster): the gurgle speeds up and falls in pitch, glugging, until a
# last slurp as it empties.
spd = lambda t: speed(in_cubic, (t - 0.38) / 0.95)
gone = lambda t: in_cubic(span(t, 0.38, 0.95))
rnd = random.Random(33)
glugs = [drop(0.38 + 0.95 * k + rnd.uniform(-0.01, 0.01), 240 - 80 * k, 400 - 100 * k, 0.018, 0.06, 0.45 + 0.4 * k)
         for k in (0.42, 0.56, 0.67, 0.76, 0.83, 0.89, 0.94)]
save("lock-drain.wav", reverb(mix(
    render(0.4, [drop(0.0, 420, 900, 0.02, 0.06, 0.7), drop(0.07, 520, 1150, 0.016, 0.05, 0.6),
                 drop(0.14, 640, 1450, 0.013, 0.05, 0.5), glass(0.0, chord, 0.16, 0.01, 0.3)]),
    bubbles(1.6, lambda t: (20 + 260 * spd(t) / 3) * (0.38 <= t < 1.36), lambda t: 950 - 600 * gone(t),
            lambda t: 0.3 + 0.25 * spd(t), seed=13),
    rush(1.6, lambda t: 1500 - 1100 * gone(t), lambda t: 0.28 * spd(t) * (t < 1.33)),
    render(1.6, glugs + [lambda t: 0.5 * whoosh_at(t)]),
), 0.25, 0.8, 0.45))

# a key: a drop into the pool (four of them, so typing doesn't repeat); deleting one: a smaller, lower plip.
for k, (f, s) in enumerate([(430, 1), (520, 2), (600, 3), (480, 4)]):
    rnd = random.Random(s)
    save(f"lock-drop-{k + 1}.wav", reverb(render(0.25, [
        drop(0.0, f, f * 2.1, 0.011, 0.045, 1.0),
        drop(0.05 + 0.03 * rnd.random(), f * 1.6, f * 3, 0.008, 0.025, 0.25),
    ]), 0.22, 0.7, 0.3))
save("lock-undrop.wav", reverb(render(0.2, [drop(0.0, 330, 560, 0.014, 0.04, 1.0)]), 0.22, 0.7, 0.3))

# splash: a wrong password. Three drops hit at once (the left, right and middle ripples), the crown of spray,
# and the pool sloshing as the chop jumps up and calms over 1.4 s.
chop = lambda t: min(1, t / 0.09) * (1 - span(t, 0.09, 1.4)) ** 2
save("lock-splash.wav", reverb(mix(
    render(0.5, [drop(0.0, 330, 700, 0.02, 0.08, 1.0), drop(0.012, 400, 860, 0.018, 0.07, 0.8),
                 drop(0.025, 290, 620, 0.022, 0.09, 1.0), boom(0.0, 140, 70, 0.4, 0.08)]),
    rush(1.6, lambda t: 2600 - 1700 * span(t, 0, 0.3), lambda t: 0.9 * math.exp(-t / 0.06) + 0.3 * chop(t), q=0.8),
    bubbles(1.6, lambda t: 230 * chop(t), lambda t: 750 - 250 * span(t, 0, 1.4), lambda t: 0.25 + 0.5 * chop(t), seed=14),
), 0.28, 0.9, 0.5))

print("made", ", ".join(sorted(p.name for p in HERE.glob("*.wav"))))
