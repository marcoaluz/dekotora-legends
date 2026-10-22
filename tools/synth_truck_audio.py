"""T-197: synthesized truck/tram sounds (diesel engine loops, jake brake, open-pipe rasp, overrun pops, gearbox
air "pfft", parking air brake, tyre/road roar, tram bell and tram running loop). Deterministic (fixed seeds).

Run with the system Python (numpy only, no scipy):
    python tools/synth_truck_audio.py                 # writes everything into game/assets/audio/
    python tools/synth_truck_audio.py --out DIR       # writes into DIR/engines, DIR/sfx/... (previews)
    python tools/synth_truck_audio.py --only i6       # only names containing "i6"

How the engine loops are built (why they sound like a diesel and not like a pitched tape):
  * every combustion is an exhaust pressure pulse placed at the real firing time of each cylinder (I6 = 3 per
    revolution, V8 cross-plane = uneven per bank "LRRLRLLR", I4 = 2 per revolution);
  * each cylinder has a fixed strength bias and every cycle a random variation -> the irregular low "chug" at idle;
  * a sharp blowdown transient + noise burst per pulse (more with load) and a diesel "clatter" click per injection;
  * the exhaust system is a chain of causal filters (muffler boom, pipe resonance, low-pass, pipe echo comb) applied
    in the frequency domain on a loop of an integer number of engine cycles -> the loop is seamless;
  * loops are rendered at fixed RPM points (on load / off load), so the game only pitches each loop by +-20%.
Loops carry a WAV "smpl" loop chunk (Godot imports them already looping).
"""
import os
import struct
import sys
import wave

import numpy as np

SR = 24000
TAU = 2.0 * np.pi
RPM_POINTS = [700, 1000, 1400, 1900, 2500]
JAKE_POINTS = [1300, 1800, 2400]
OPEN_POINTS = [1000, 1600, 2300]

# firing pattern: (phase in the 720 deg cycle, cylinder, bank gain). V8 cross-plane: the near bank is louder.
PAT_I6 = [(k / 6.0, k, 1.0) for k in range(6)]
PAT_I4 = [(k / 4.0, k, 1.0) for k in range(4)]
PAT_V8 = [(k / 8.0, k, 1.0 if b == "L" else 0.58) for k, b in enumerate("LRRLRLLR")]

VOICES = {
    # lp = muffler low-pass, boom/mid = (Hz, Q, dB) peaks, comb = (pipe echo s, gain), drive = grit
    "i6": dict(pat=PAT_I6, lp=1900.0, boom=(105.0, 1.0, 3.0), mid=(520.0, 1.0, 7.0), comb=(0.0075, 0.35),
               drive=2.0, clatter=0.55, bias=0.10, width=0.06, level=1.0, seed=11),
    "i6t": dict(pat=PAT_I6, lp=2700.0, boom=(118.0, 1.1, 3.0), mid=(640.0, 1.0, 8.0), comb=(0.0062, 0.42),
                drive=2.7, clatter=0.45, bias=0.08, width=0.05, level=1.0, seed=23),
    "v8": dict(pat=PAT_V8, lp=2300.0, boom=(85.0, 0.9, 4.0), mid=(420.0, 0.9, 7.0), comb=(0.0092, 0.45),
               drive=2.9, clatter=0.35, bias=0.12, width=0.06, level=1.0, seed=37),
    "i4": dict(pat=PAT_I4, lp=2500.0, boom=(150.0, 1.2, 3.0), mid=(760.0, 1.2, 7.0), comb=(0.0052, 0.30),
               drive=1.8, clatter=0.8, bias=0.14, width=0.06, level=0.85, seed=41),
}


# ---------------------------------------------------------------- filters (RBJ biquads, evaluated on the FFT grid)
def rbj(kind, f0, q=0.707, gain_db=0.0):
    w0 = TAU * f0 / SR
    cw, sw = np.cos(w0), np.sin(w0)
    al = sw / (2.0 * q)
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b, a = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2], [1 + al, -2 * cw, 1 - al]
    elif kind == "hp":
        b, a = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2], [1 + al, -2 * cw, 1 - al]
    elif kind == "bp":
        b, a = [al, 0.0, -al], [1 + al, -2 * cw, 1 - al]
    elif kind == "peak":
        b, a = [1 + al * A, -2 * cw, 1 - al * A], [1 + al / A, -2 * cw, 1 - al / A]
    else:
        raise ValueError(kind)
    return np.array(b), np.array(a)


def response(n, stages):
    w = TAU * np.arange(n // 2 + 1) / n
    z1 = np.exp(-1j * w)
    z2 = z1 * z1
    h = np.ones_like(z1)
    for st in stages:
        if st[0] == "comb":                       # feedback comb: pipe echo (delay s, gain)
            h = h / (1.0 - st[2] * np.exp(-1j * w * st[1] * SR))
        else:
            b, a = rbj(*st)
            h = h * (b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2)
    return h


def filt(x, stages):
    """Circular (loop-safe) causal filtering. For one-shots pad with silence first."""
    n = len(x)
    return np.fft.irfft(np.fft.rfft(x) * response(n, stages), n=n)


def add_at(buf, t0, v):
    i0 = int(np.floor(t0 * SR))
    idx = (np.arange(len(v)) + i0) % len(buf)
    np.add.at(buf, idx, v)


def alpha_pulse(tau, frac, length):
    t = (np.arange(length) + 1.0 - frac) / SR
    return (t / tau) * np.exp(1.0 - t / tau)


def burst(rng, tau, frac, length):
    t = (np.arange(length) + 1.0 - frac) / SR
    return rng.standard_normal(length) * np.exp(-t / tau)


def soft(x, drive):
    return np.tanh(drive * x) / np.tanh(drive)


# ---------------------------------------------------------------- engine loops
def loop_frames(rpm, seconds):
    cyc = 120.0 / rpm
    nc = max(4, int(round(seconds / cyc)))
    n = int(round(nc * cyc * SR))
    return n, nc, n / SR / nc


def render_engine(voice, rpm, mode):
    """mode: on (full load) | off (overrun fuel cut; at 700 rpm = idle) | jake | open (rasp layer, on load)."""
    v = VOICES[voice]
    pat = v["pat"]
    ncyl = len(pat)
    idle = rpm <= 750
    n, nc, cyc = loop_frames(rpm, 2.4 if idle else 1.6)
    rng = np.random.default_rng(v["seed"] * 1000 + rpm + {"on": 1, "off": 2, "jake": 3, "open": 4}[mode])
    bias = 1.0 + v["bias"] * np.random.default_rng(v["seed"]).standard_normal(ncyl)   # same in every loop
    interval = cyc / ncyl
    if mode == "on":
        load = 1.0
    elif mode == "off":
        load = 0.22 if idle else 0.0
    else:
        load = 1.0 if mode == "open" else 0.0
    sig = 0.14 if idle else (0.10 if load > 0.5 else 0.16)
    ex_l = np.zeros(n)
    ex_r = np.zeros(n)
    clat = np.zeros(n)
    tau = v["width"] * interval
    plen = int(min(8.0 * tau, 3.0 * interval) * SR) + 4
    for c in range(nc):
        for ph, cyl, bank in pat:
            t = (c + ph) * cyc + rng.normal(0.0, 0.012 if idle else 0.006) * interval
            t %= n / SR
            frac = t * SR - np.floor(t * SR)
            amp = bank * bias[cyl] * max(0.2, 1.0 + sig * rng.standard_normal())
            buf = ex_l if bank >= 1.0 else ex_r
            if mode == "jake":                          # compression release: sharp bark, no combustion
                p = 1.7 * alpha_pulse(0.00028, frac, 64)
                nb = burst(rng, min(0.0045, 0.35 * interval), frac, int(0.02 * SR))
                add_at(buf, t, amp * p)
                add_at(buf, t, amp * 0.55 * nb)
                add_at(buf, t, amp * 0.10 * alpha_pulse(tau, frac, plen))
                continue
            main = 0.12 + 0.88 * load if load > 0.0 else 0.13           # fuel cut: only pumping
            add_at(buf, t, amp * main * alpha_pulse(tau, frac, plen))
            if load > 0.0:
                add_at(buf, t, amp * (0.5 + 0.9 * load) * alpha_pulse(0.00045, frac, 48))
                nb = burst(rng, min(0.006, 0.28 * interval), frac, int(0.03 * SR))
                add_at(buf, t, amp * (0.15 + 0.45 * load) * (rpm / 1400.0) ** 0.6 * nb)
                ck = burst(rng, 0.0009, frac, int(0.008 * SR))
                ring = np.sin(TAU * 3100.0 * np.arange(len(ck)) / SR) * np.exp(-np.arange(len(ck)) / (0.0022 * SR))
                add_at(clat, t + 0.0006, amp * (1.0 + 0.35 * rng.standard_normal()) * (ck + 0.6 * ring))
            else:
                ck = burst(rng, 0.0007, frac, int(0.006 * SR))
                add_at(clat, t + 0.0006, 0.18 * ck)                      # valve train only
    lp = v["lp"] * (2.2 if mode == "open" else (1.5 if mode == "jake" else 1.0)) * (1.0 + 0.5 * (rpm - 700) / 1800.0)
    chain = [("hp", 40.0, 0.7), ("peak",) + v["boom"], ("peak",) + v["mid"], ("lp", lp, 0.8),
             ("lp", lp * 1.7, 0.7), ("comb", v["comb"][0], v["comb"][1])]
    ex = filt(ex_l, chain) + filt(ex_r, chain[:-1] + [("comb", v["comb"][0] * 1.23, v["comb"][1])])
    ex /= max(1e-9, np.sqrt(np.mean(ex ** 2))) * 3.5          # common working level before the grit
    drive = v["drive"] * (1.8 if mode == "open" else (1.6 if mode == "jake" else (0.8 + 0.4 * load)))
    gain_by_load = {"on": 1.0, "open": 1.0, "jake": 0.85}.get(mode, 1.0 if idle else 0.22)
    rate = (rpm / 1500.0) ** 0.5                                  # more pulses per second = louder
    ex = soft(ex, drive) * gain_by_load * rate
    ex = filt(ex, [("hp", 55.0, 0.7), ("peak", 900.0, 0.5, 6.0)])       # small speakers: keep the growl audible
    if mode == "open":
        return filt(ex, [("hp", 260.0, 0.7), ("peak", 1400.0, 0.9, 4.0)]) * 0.8
    clat = filt(clat, [("hp", 1400.0, 0.7), ("lp", 5200.0, 0.7), ("peak", 2600.0, 2.0, 4.0)])
    clat *= v["clatter"] * 0.05 / max(1e-9, np.sqrt(np.mean(clat ** 2))) * (1.0 if idle else 0.7) * (0.4 if load == 0.0 else 1.0)
    t = np.arange(n) / SR
    crank = 1.0 + 0.3 * np.sin(TAU * t * nc * 2.0 / (n / SR))           # once per revolution (2 per cycle)
    mech = filt(np.random.default_rng(rpm).standard_normal(n), [("bp", 700.0 + rpm * 0.6, 0.7), ("lp", 4000.0, 0.7)])
    mech *= 0.03 * (rpm / 1500.0) / max(1e-9, np.sqrt(np.mean(mech ** 2))) * crank
    intake = filt(np.random.default_rng(rpm + 7).standard_normal(n), [("hp", 300.0, 0.7), ("lp", 1800.0, 0.7)])
    intake *= (0.012 + 0.05 * load) * (rpm / 2000.0) / max(1e-9, np.sqrt(np.mean(intake ** 2)))
    return (ex + clat + mech + intake) * v["level"]


# ---------------------------------------------------------------- one-shots and other loops
def fade(x, a=0.004, b=0.03):
    n = len(x)
    e = np.ones(n)
    na, nb = int(a * SR), int(b * SR)
    e[:na] = np.linspace(0, 1, na)
    e[n - nb:] = np.linspace(1, 0, nb)
    return x * e


def one_shot(x, stages, tail=0.3):
    y = filt(np.concatenate([x, np.zeros(int(tail * SR))]), stages)
    return fade(y)


def exh_pop(seed):
    rng = np.random.default_rng(seed)
    n = int(0.12 * SR)
    x = np.zeros(n)
    x[:64] += 2.0 * alpha_pulse(0.0003, 0.0, 64)
    x += burst(rng, 0.012, 0.0, n) * 0.7
    y = one_shot(x, [("hp", 70.0, 0.7), ("peak", 110.0, 1.0, 6.0), ("lp", 2600.0, 0.8), ("comb", 0.007, 0.4)], 0.25)
    return soft(y / np.max(np.abs(y)), 2.5)


def gear_pfft():
    rng = np.random.default_rng(5)
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    env = np.minimum(t / 0.008, 1.0) * np.exp(-t / 0.09)
    x = rng.standard_normal(n) * env
    clunk = alpha_pulse(0.004, 0.0, n) * 0.6
    return one_shot(x, [("hp", 1500.0, 0.7), ("lp", 7000.0, 0.7)], 0.05) + one_shot(clunk, [("lp", 400.0, 0.7)], 0.05)


def air_park():
    rng = np.random.default_rng(6)
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    env = np.minimum(t / 0.012, 1.0) * (0.35 + 0.65 * np.exp(-t / 0.18)) * np.clip((1.1 - t) / 0.5, 0, 1)
    x = rng.standard_normal(n) * env
    return one_shot(x, [("hp", 1800.0, 0.7), ("peak", 4200.0, 1.2, 5.0), ("lp", 9000.0, 0.7)], 0.05)


def tyre_loop():
    n = int(2.0 * SR)
    rng = np.random.default_rng(8)
    x = filt(rng.standard_normal(n), [("hp", 90.0, 0.7), ("peak", 420.0, 0.8, 6.0), ("lp", 1600.0, 0.7)])
    t = np.arange(n) / SR
    wob = 1.0 + 0.12 * np.sin(TAU * t * 3.0 / 2.0) + 0.06 * np.sin(TAU * t * 7.0 / 2.0)
    return x * wob


def tram_bell():
    """Japanese street car "chin-chin": two strikes of a small bell. Inharmonic partials (metal plate/bell)."""
    dur = 2.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    f0 = 1180.0
    parts = [(1.0, 1.0, 0.9), (2.32, 0.55, 0.6), (2.98, 0.35, 0.45), (4.13, 0.25, 0.3), (5.41, 0.15, 0.22),
             (0.51, 0.25, 1.2)]
    rng = np.random.default_rng(9)
    for k, t0 in enumerate([0.0, 0.30]):
        tt = t - t0
        on = tt >= 0
        g = 1.0 if k == 0 else 0.85
        for r, a, d in parts:
            out[on] += g * a * np.sin(TAU * f0 * r * tt[on] + r) * np.exp(-tt[on] / d)
        strike = burst(rng, 0.002, 0.0, int(0.02 * SR))
        add_at(out, t0, 0.5 * g * filt(np.concatenate([strike, np.zeros(64)]), [("hp", 2500.0, 0.7)])[:len(strike)])
    out[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    return fade(out, 0.001, 0.05)


def tram_run_loop():
    """Light rail running: soft electric motor hum, light wheel/rail rolling, few joint clicks, faint flange squeal.
    Much lighter and higher than the freight train rumble. 4 s seamless loop."""
    dur = 4.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(10)
    roll = filt(rng.standard_normal(n), [("hp", 250.0, 0.7), ("peak", 900.0, 0.8, 5.0), ("lp", 3500.0, 0.7)])
    roll /= np.sqrt(np.mean(roll ** 2))
    roll *= 1.0 + 0.15 * np.sin(TAU * t * 2.0 / dur)
    body = filt(rng.standard_normal(n), [("hp", 60.0, 0.7), ("lp", 260.0, 0.7)])   # light low body (not the train rumble)
    roll += 0.8 * body / np.sqrt(np.mean(body ** 2))
    # traction motor: low hum with a few partials, tiny wobble (not a melody); integer cycles per loop
    hum = np.zeros(n)
    for f, a in [(220.0, 0.5), (440.0, 0.3), (660.0, 0.12), (1320.0, 0.06)]:
        fq = round(f * dur) / dur
        hum += a * np.sin(TAU * fq * t + 0.4 * np.sin(TAU * t * 1.0 / dur))
    hum = filt(hum, [("lp", 2000.0, 0.7)])
    # rail joints: two quick clicks (one bogie) per joint, light
    clicks = np.zeros(n)
    for t0 in [0.35, 1.55, 2.75, 3.4]:
        for dt in (0.0, 0.11):
            add_at(clicks, t0 + dt, burst(rng, 0.004, 0.0, int(0.03 * SR)))
    clicks = filt(clicks, [("hp", 300.0, 0.7), ("lp", 2500.0, 0.7)])
    # flange squeal: narrow band around 3.4 kHz fading in and out once per loop
    sq = filt(rng.standard_normal(n), [("bp", 3400.0, 25.0)])
    sq /= np.sqrt(np.mean(sq ** 2))
    sq *= np.clip(np.sin(TAU * t / dur - 1.0), 0, 1) ** 3
    return 0.20 * roll + 0.09 * hum / np.sqrt(np.mean(hum ** 2)) * 0.25 + 0.5 * clicks / max(1e-9, np.max(np.abs(clicks))) * 0.3 + 0.03 * sq


# ---------------------------------------------------------------- output
def write_wav(path, x, loop):
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    if loop:                                      # smpl chunk: one forward loop over the whole file
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(pcm), 0, 0)
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
            size = f.tell() - 8
            f.seek(4)
            f.write(struct.pack("<I", size))


def jobs():
    out = []
    for vc in VOICES:
        for r in RPM_POINTS:
            out.append(("engines", "syn_%s_on_%d" % (vc, r), lambda vc=vc, r=r: render_engine(vc, r, "on"), True, vc))
            out.append(("engines", "syn_%s_off_%d" % (vc, r), lambda vc=vc, r=r: render_engine(vc, r, "off"), True, vc))
        for r in JAKE_POINTS:
            out.append(("engines", "syn_%s_jake_%d" % (vc, r), lambda vc=vc, r=r: render_engine(vc, r, "jake"), True, vc))
        for r in OPEN_POINTS:
            out.append(("engines", "syn_%s_open_%d" % (vc, r), lambda vc=vc, r=r: render_engine(vc, r, "open"), True, vc))
    out += [("engines", "syn_exh_pop_1", lambda: exh_pop(1) * 0.7, False, ""),
            ("engines", "syn_exh_pop_2", lambda: exh_pop(2) * 0.6, False, ""),
            ("sfx/truck", "gear_air_pfft", lambda: gear_pfft(), False, ""),
            ("sfx/truck", "air_brake_park", lambda: air_park(), False, ""),
            ("sfx/truck", "tyre_road_loop", lambda: tyre_loop(), True, ""),
            ("sfx/ambient", "tram_bell", lambda: tram_bell(), False, ""),
            ("sfx/ambient", "tram_run_loop", lambda: tram_run_loop(), True, "")]
    return out


def tram_passby(path, speed=18.0, side=25.0, dur=12.0):
    """Preview only (docs/audio_t197): the tram passing 25 m away at 18 m/s with distance and Doppler, bell on the
    way in. Mimics the game (AudioStreamPlayer3D inverse distance, unit 22 m; Doppler limited to +-6%)."""
    run, bell = tram_run_loop(), tram_bell()
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = (t - dur / 2) * speed
    d = np.sqrt(x ** 2 + side ** 2)
    radial = np.gradient(d, 1.0 / SR)
    pitch = np.clip(343.0 / (343.0 + radial), 0.94, 1.06)
    pos = np.cumsum(pitch) % len(run)
    i0 = np.floor(pos).astype(int)
    fr = pos - i0
    y = run[i0] * (1 - fr) + run[(i0 + 1) % len(run)] * fr
    g = np.minimum(1.0, 22.0 / d)
    out = y * g
    tb = int(3.0 * SR)
    out[tb:tb + len(bell)] += bell[:n - tb] * 0.6 * float(np.minimum(1.0, 22.0 / d[tb]))
    out = fade(out / np.max(np.abs(out)) * 0.8, 0.2, 0.3)
    write_wav(path, out, False)


def main():
    args = sys.argv[1:]
    if "--tram-demo" in args:
        tram_passby(args[args.index("--tram-demo") + 1])
        return
    root = args[args.index("--out") + 1] if "--out" in args else os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio")
    only = args[args.index("--only") + 1] if "--only" in args else ""
    rendered = {}
    for folder, name, fn, loop, group in jobs():
        if only and only not in name:
            continue
        rendered[name] = (folder, fn(), loop, group)
    # engine loops: one gain per voice (keeps on/off/rpm balance), peak of the loudest loop at -1 dBFS;
    # one-shots: normalised to their own peak (scaled in the game).
    peaks = {}
    for name, (folder, x, loop, group) in rendered.items():
        if group:
            peaks[group] = max(peaks.get(group, 0.0), float(np.max(np.abs(x))))
    for name, (folder, x, loop, group) in rendered.items():
        pk = peaks[group] if group else float(np.max(np.abs(x)))
        x = x * (0.89 / max(pk, 1e-9))
        d = os.path.join(root, folder)
        os.makedirs(d, exist_ok=True)
        write_wav(os.path.join(d, name + ".wav"), x, loop)
        print("%-24s %5.2f s  rms %6.1f dBFS" % (name, len(x) / SR, 20 * np.log10(max(1e-9, np.sqrt(np.mean(x ** 2))))))


if __name__ == "__main__":
    main()
