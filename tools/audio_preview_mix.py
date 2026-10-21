"""Offline copy of the garage "OUVIR" preview (SoundPreview + EngineAudio, T-173/T-178), rendered to WAV.
Run in Blender: blender -b --factory-startup -P mix_preview.py -- OUT_DIR MODE DIR1 [DIR2 ...]
MODE = old (turbo pitch 0.8..1.5) | new (0.85..1.2). Files are searched in DIR1, DIR2... (first hit wins)."""
import os
import sys
import wave

import aud
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, mode, dirs = args[0], args[1], args[2:]
os.makedirs(out_dir, exist_ok=True)
RATE = 44100
DT = 1.0 / 60.0
DUR = 3.0
_cache = {}

GAINS_OLD = {"exh_pop_high": 5.0, "exh_stack_idle": -2.0}
GAINS = GAINS_OLD if mode == "old" else {"exh_pop_idle": 3.0, "exh_pop_mid": 2.0, "exh_pop_high": 5.0,
                                         "exh_stack_idle": 1.5, "exh_stack_mid": 1.5, "exh_stack_high": 1.5}


def load(name):
    if name in _cache:
        return _cache[name]
    for d in dirs:
        p = os.path.join(d, name + ".mp3")
        if os.path.exists(p):
            s = aud.Sound(p)
            x = np.asarray(s.data(), dtype=np.float64)
            x = x.mean(axis=1) if x.ndim == 2 else x
            _cache[name] = x
            return x
    raise FileNotFoundError(name)


def band_weights(r, centers, width):
    w = []
    for c in centers:
        v = min(max(1.0 - abs(r - c) / width, 0.0), 1.0)
        w.append(v * v * (3 - 2 * v))
    t = sum(w)
    if t <= 1e-4:
        w[0], t = 1.0, 1.0
    return [v / t for v in w]


def rev_curve(t):
    if t < 0.4:
        return 0.05, 0.0
    if t < 1.6:
        return 0.05 + (0.92 - 0.05) * (t - 0.4) / 1.2, 1.0
    if t < 1.9:
        return 0.92, 1.0
    return 0.92 + (0.05 - 0.92) * min(max((t - 1.9) / 1.0, 0.0), 1.0), 0.0


def db2lin(db):
    return 10 ** (db / 20.0)


def render(spec, name):
    bands = spec["bands"]
    centers = [0.0, 0.3, 0.62, 0.95] if len(bands) == 4 else [0.0, 0.5, 0.95]
    width = 0.34 if len(bands) == 4 else 0.5
    layers = ["%s_%s" % (spec["set"], b) for b in bands]
    if spec["turbo"]:
        layers.append(spec["turbo"])
    nframes = int(DUR / DT)
    vol = {l: np.zeros(nframes) for l in layers}
    pit = {l: np.ones(nframes) for l in layers}
    st, sr = 0.0, 0.0
    blow_frame = -1
    for f in range(nframes):
        t = (f + 1) * DT
        rpm, thr = rev_curve(t)
        boost = min(max((t - 0.8) / 0.8, 0.0), 1.0) if thr > 0.5 else max(0.0, 1.0 - (t - 1.9) / 0.4)
        if mode != "old":
            boost = min(max(boost, 0.0), 1.0) if (thr > 0.5 or t >= 1.9) else 0.0
        if thr < 0.5 and t >= 1.9 and blow_frame < 0 and spec["turbo"]:
            blow_frame = f
        st += (thr - st) * min(6 * DT, 1)
        sr += (rpm - sr) * min(10 * DT, 1)
        w = band_weights(sr, centers, width)
        ld = 0.55 + 0.45 * st
        p = (0.78 + min(max(sr, 0), 1) * 0.62) * spec["pitch"]
        fade = min(max((DUR - t) / 0.4, 0.0), 1.0)
        for i, l in enumerate(layers[:len(bands)]):
            g = -2.0 + GAINS.get(l, 0.0)
            vol[l][f] = (min(max(w[i] * ld, 0), 1) * db2lin(g) if w[i] * ld > 0.003 else 0.0) * fade
            pit[l][f] = p
        if spec["turbo"]:
            l = spec["turbo"]
            tp = (0.8 + boost * 0.7) if mode == "old" else (0.85 + 0.35 * boost)
            g = -6.0 + spec["turbo_db"]
            vol[l][f] = (boost * 0.75 * db2lin(g) if boost * 0.75 > 0.003 else 0.0) * fade
            pit[l][f] = tp * spec["turbo_pitch"]
    n = int(DUR * RATE)
    tt = np.arange(n) / RATE
    fx = np.arange(nframes) * DT
    out = np.zeros(n)
    for l in layers:
        x = load(l)
        v = np.interp(tt, fx, vol[l])
        pr = np.interp(tt, fx, pit[l])
        phase = np.cumsum(pr)
        idx = phase % len(x)
        i0 = idx.astype(int)
        fr = idx - i0
        out += v * (x[i0] * (1 - fr) + x[(i0 + 1) % len(x)] * fr)
    if blow_frame >= 0:
        b = load(spec["blowoff"]) * db2lin(-4.0)
        s0 = int((blow_frame + 1) * DT * RATE)
        m = min(len(b), n - s0)
        out[s0:s0 + m] += b[:m]
    peak = np.max(np.abs(out)) + 1e-9
    out = out / max(peak, 1.0) * 0.98
    with wave.open(os.path.join(out_dir, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((out * 32767).astype(np.int16).tobytes())


B4 = ["idle", "low", "mid", "high"]
B3 = ["idle", "mid", "high"]
COMBOS = {
    "i6std_turbo_simples": {"set": "i6_std", "bands": B4, "pitch": 1.0, "turbo": "turbo_single_whine", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoff": "turbo_blowoff_2"},
    "i6std_turbo_duplo": {"set": "i6_std", "bands": B4, "pitch": 1.0, "turbo": "turbo_twin_whine", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoff": "turbo_blowoff_1"},
    "i6preparado_sem_turbo": {"set": "i6_tuned", "bands": B4, "pitch": 1.0, "turbo": "", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoff": ""},
    "v8_sem_turbo": {"set": "v8", "bands": B4, "pitch": 1.0, "turbo": "", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoff": ""},
    "v8_turbo_duplo": {"set": "v8", "bands": B4, "pitch": 1.0, "turbo": "turbo_twin_whine", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoff": "turbo_blowoff_2"},
    "v8_chamines_turbo_duplo": {"set": "exh_stack", "bands": B3, "pitch": 0.9, "turbo": "exh_stack_turbo_whine", "turbo_pitch": 1.1, "turbo_db": 2.0, "blowoff": "exh_stack_blowoff"},
    "i6_escape_direto_turbo_simples": {"set": "exh_rasp", "bands": B3, "pitch": 1.0, "turbo": "exh_rasp_turbo_whine", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoff": "exh_rasp_blowoff"},
    "i6_cromado_turbo_simples": {"set": "exh_pop", "bands": B3, "pitch": 1.0, "turbo": "exh_pop_turbo_whine", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoff": "exh_pop_blowoff"},
}
only = os.environ.get("T178_ONLY", "")
for k, sp in COMBOS.items():
    if only and only not in k:
        continue
    render(sp, k)
print("MIX_DONE", out_dir)
