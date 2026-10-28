"""T-260: offline preview of the engine loops with the game's mixing rules (DieselMix: two nearest rpm points, equal
power, pitch = rpm / point, ON/OFF by load), so the loops can be heard in any player and measured without Godot.

    python -P tools/demo_engine_t260.py [--voices i4,i6,i6t] [--src rec,syn] [--out docs/audio_t260] [--eng DIR_OF_REC_LOOPS]

Script (20 s): idle 2 s, foot down 700 -> 2400 rpm with two upshifts, hold, foot off down to 1000, blip to 1900, idle.
Writes demo_<voice>_<src>.wav (32 kHz mono) and demo_roteiro.txt (time, rpm, load every 0.5 s).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_plot as ap  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ENG = os.path.join(ROOT, "game", "assets", "audio", "engines")
POINTS = [700.0, 1000.0, 1400.0, 1900.0, 2500.0]
SR = 32000
BLOCK = 128
# (time s, rpm, load) keys; linear in between
KEYS = [(0.0, 700, 0.0), (2.0, 700, 0.0), (2.3, 800, 1.0), (5.0, 1900, 1.0), (5.25, 1250, 0.0), (5.45, 1300, 1.0),
        (8.0, 2200, 1.0), (8.25, 1600, 0.0), (8.45, 1650, 1.0), (11.0, 2400, 1.0), (12.5, 2400, 1.0), (12.7, 2350, 0.0),
        (15.0, 1000, 0.0), (15.3, 1100, 1.0), (16.3, 1900, 1.0), (16.5, 1850, 0.0), (18.0, 750, 0.0), (20.0, 700, 0.0)]


def point_weights(rpm):
    w = np.zeros(len(POINTS))
    if rpm <= POINTS[0]:
        w[0] = 1.0
    elif rpm >= POINTS[-1]:
        w[-1] = 1.0
    else:
        for i in range(len(POINTS) - 1):
            if rpm < POINTS[i + 1]:
                f = (rpm - POINTS[i]) / (POINTS[i + 1] - POINTS[i])
                w[i], w[i + 1] = np.cos(f * np.pi / 2), np.sin(f * np.pi / 2)
                break
    return w


def load_layer(path):
    x, sr = ap.read_wav(path)
    if sr != SR:
        x = ap.resample(x, sr, SR)
    return x


def render(voice, src, eng=ENG):
    layers = {}
    for p in POINTS:
        for k in ("on", "off"):
            layers[(k, p)] = load_layer(os.path.join(eng if src == "rec" else ENG, "%s_%s_%s_%d.wav" % (src, voice, k, int(p))))
    dur = KEYS[-1][0]
    n = int(dur * SR)
    out = np.zeros(n)
    pos = {key: 0.0 for key in layers}
    kt = np.array([k[0] for k in KEYS])
    load_s = 0.0
    gains = {key: 0.0 for key in layers}
    for b0 in range(0, n, BLOCK):
        t = b0 / SR
        rpm = float(np.interp(t, kt, [k[1] for k in KEYS]))
        target = float(np.interp(t, kt, [k[2] for k in KEYS]))
        load_s += (target - load_s) * min(BLOCK / SR * (5.0 if target > load_s else 10.0), 1.0)
        pw = point_weights(rpm)
        lw = (np.sin(load_s * np.pi / 2), np.cos(load_s * np.pi / 2))
        m = min(BLOCK, n - b0)
        for (k, p), x in layers.items():
            g_new = pw[POINTS.index(p)] * (lw[0] if k == "on" else lw[1])
            g = np.linspace(gains[(k, p)], g_new, m)
            gains[(k, p)] = g_new
            if g_new < 1e-4 and g[0] < 1e-4:
                continue
            step = rpm / p
            idx = pos[(k, p)] + step * np.arange(m)
            i0 = np.floor(idx).astype(int)
            fr = idx - i0
            L = len(x)
            out[b0:b0 + m] += g * (x[i0 % L] * (1 - fr) + x[(i0 + 1) % L] * fr)
            pos[(k, p)] = (pos[(k, p)] + step * m) % L
    pk = np.max(np.abs(out))
    return out * (0.89 / pk if pk > 0.89 else 1.0)


def main():
    a = sys.argv[1:]

    def opt(k, d):
        return a[a.index(k) + 1] if k in a else d
    out_dir = opt("--out", os.path.join(ROOT, "docs", "audio_t260"))
    os.makedirs(out_dir, exist_ok=True)
    for voice in opt("--voices", "i4,i6,i6t").split(","):
        for src in opt("--src", "rec,syn").split(","):
            y = render(voice, src, opt("--eng", ENG))
            path = os.path.join(out_dir, "demo_%s_%s.wav" % (voice, src))
            ap.write_wav(path, y, SR)
            print("DEMO %s  %.1f s  RMS %.1f dBFS" % (path, len(y) / SR, 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)))
    kt = np.array([k[0] for k in KEYS])
    with open(os.path.join(out_dir, "demo_roteiro.txt"), "w", encoding="utf-8") as f:
        f.write("tempo_s rpm acelerador\n")
        for t in np.arange(0, KEYS[-1][0] + 0.01, 0.5):
            f.write("%.1f %.0f %.0f%%\n" % (t, np.interp(t, kt, [k[1] for k in KEYS]), 100 * np.interp(t, kt, [k[2] for k in KEYS])))


if __name__ == "__main__":
    main()
