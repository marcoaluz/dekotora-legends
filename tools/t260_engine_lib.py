"""T-260: building blocks to turn free-revving recordings into fixed-RPM engine loops (system Python + numpy only).

- rpm_track: firing frequency per 10 ms frame (harmonic sum minus half-harmonics, Viterbi path = no octave jumps).
- classify: idle / on (revving up or held loud) / off (falling, foot off) per frame.
- warp_run: order-tracking resample of one stretch so the firing frequency becomes EXACTLY a target (pitch flattening:
  the waveform follows the engine's own cycle, so the firing rhythm stays natural).
- formant_shift: moves the spectral envelope (resonances of the exhaust/body) by a factor, keeping the harmonics.
- stitch: joins grains with the same period: aligns each new grain to the tail by cross-correlation, then crossfades.
"""
import numpy as np

import audio_plot as ap

AN_SR = 4000
HOP_S = 0.01
F_LO, F_HI = 20.0, 140.0
STEPS_PER_OCT = 96


def rpm_track(x, sr, cyl):
    """Returns (t, f_hz, score). f = firing frequency (rpm = f x 120 / cyl)."""
    lo = ap.resample(ap.fft_lowpass(x, sr, 900.0), sr, AN_SR)
    win, hop, nfft = 1024, int(HOP_S * AN_SR), 8192
    hann = np.hanning(win)
    pad = np.concatenate([np.zeros(win // 2), lo, np.zeros(win // 2)])
    n_fr = (len(pad) - win) // hop + 1
    idx = np.arange(win)[None, :] + hop * np.arange(n_fr)[:, None]
    spec = np.abs(np.fft.rfft(pad[idx] * hann, nfft, axis=1)).astype(np.float32)   # frames x bins
    L = np.log(spec + 1e-6)
    # whitening: peak height over the local median level (40 Hz wide)
    bw = int(40.0 / (AN_SR / nfft))
    k = np.ones(bw, np.float32) / bw
    base = np.apply_along_axis(lambda r: np.convolve(r, k, mode="same"), 1, L)
    P = np.clip(L - base, 0.0, None)
    df = AN_SR / nfft
    cands = F_LO * 2.0 ** (np.arange(int(np.log2(F_HI / F_LO) * STEPS_PER_OCT) + 1) / STEPS_PER_OCT)
    score = np.zeros((n_fr, len(cands)), np.float32)
    for i, f in enumerate(cands):
        kk = np.arange(1, int(450.0 / f) + 1)
        on = P[:, np.round(kk * f / df).astype(int)].mean(axis=1)
        half = P[:, np.round((kk - 0.5) * f / df).astype(int)].mean(axis=1)
        score[:, i] = on - 0.5 * half
    # Viterbi: at most ~6 % change per 10 ms, small cost per step
    max_d, cost = 8, 0.12
    acc = score[0].copy()
    back = np.zeros((n_fr, len(cands)), np.int16)
    for t in range(1, n_fr):
        best = np.full(len(cands), -1e9, np.float32)
        arg = np.zeros(len(cands), np.int16)
        for d in range(-max_d, max_d + 1):
            sh = np.roll(acc, d) - cost * abs(d)
            if d > 0:
                sh[:d] = -1e9
            elif d < 0:
                sh[d:] = -1e9
            better = sh > best
            best[better] = sh[better]
            arg[better] = d
        acc = best + score[t]
        back[t] = arg
    path = np.zeros(n_fr, int)
    path[-1] = int(np.argmax(acc))
    for t in range(n_fr - 1, 0, -1):
        path[t - 1] = path[t] - back[t, path[t]]
    # parabolic refinement on the score
    f = np.empty(n_fr)
    sc = np.empty(n_fr)
    for t in range(n_fr):
        i = int(np.clip(path[t], 1, len(cands) - 2))
        a, b, c = score[t, i - 1], score[t, i], score[t, i + 1]
        den = a - 2 * b + c
        sh = 0.5 * (a - c) / den if abs(den) > 1e-9 else 0.0
        f[t] = cands[i] * 2.0 ** (np.clip(sh, -1, 1) / STEPS_PER_OCT)
        sc[t] = b
    f = smooth(f, 5)
    return np.arange(n_fr) * HOP_S, f, sc


def smooth(v, n):
    if n <= 1:
        return v
    med = np.array([np.median(v[max(0, i - n // 2):i + n // 2 + 1]) for i in range(len(v))])
    return np.convolve(np.pad(med, n // 2, mode="edge"), np.ones(n) / n, mode="valid")[:len(v)]


def level_track(x, sr, n_fr):
    h = int(HOP_S * sr)
    w = int(0.05 * sr)
    pad = np.concatenate([np.zeros(w // 2), x, np.zeros(w)])
    out = np.empty(n_fr)
    for i in range(n_fr):
        seg = pad[i * h:i * h + w]
        out[i] = 20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-9)
    return out


def classify(rpm, lev, idle_rpm, idle_db):
    """Per frame: 'idle', 'on', 'off' or '' (silence / start / stop)."""
    d = np.gradient(smooth(rpm, 9)) / HOP_S                     # rpm per second
    kind = np.empty(len(rpm), object)
    for i in range(len(rpm)):
        if lev[i] < idle_db - 12:
            kind[i] = ""
        elif rpm[i] < idle_rpm * 1.1 and abs(d[i]) < 400:
            kind[i] = "idle"
        elif d[i] > 250 or (abs(d[i]) <= 250 and lev[i] > idle_db + 5):
            kind[i] = "on"
        else:
            kind[i] = "off"
    return kind


def runs(mask, min_frames):
    out = []
    i, n = 0, len(mask)
    while i < n:
        if mask[i]:
            j = i
            while j + 1 < n and mask[j + 1]:
                j += 1
            if j - i + 1 >= min_frames:
                out.append((i, j + 1))
            i = j + 1
        else:
            i += 1
    return out


def warp_run(x, sr, t_fr, f_fr, i0, i1, f_target, out_sr):
    """Stretch [frame i0, i1) so its firing frequency is f_target everywhere. Returns (y at out_sr, mean ratio)."""
    ta, tb = t_fr[i0], t_fr[i1 - 1]
    s0, s1 = int(ta * sr), int(tb * sr)
    ts = np.arange(s0, s1) / sr
    f = np.interp(ts, t_fr, f_fr)
    phase = np.concatenate([[0.0], np.cumsum(f[:-1]) / sr])     # cycles since ta
    n_out = int(phase[-1] / f_target * out_sr)
    if n_out < 16:
        return None, 1.0
    cyc = np.arange(n_out) * f_target / out_sr
    t_src = np.interp(cyc, phase, ts)
    y = np.interp(t_src * sr, np.arange(len(x)), x)
    return y, float(np.mean(f_target / f))


def formant_shift(y, sr, gamma, max_db=12.0):
    """Moves the spectral envelope by gamma (<1 = lower resonances = bigger engine/exhaust), harmonics untouched."""
    if abs(gamma - 1.0) < 0.02 or len(y) < 2048:
        return y
    n, hop = 2048, 512
    hann = np.hanning(n)
    pad = np.concatenate([np.zeros(n), y, np.zeros(n)])
    out = np.zeros_like(pad)
    norm = np.zeros_like(pad)
    freqs = np.arange(n // 2 + 1)
    lifter = int(0.003 * sr)                                    # 3 ms: envelope smoother than ~330 Hz
    for s in range(0, len(pad) - n, hop):
        X = np.fft.rfft(pad[s:s + n] * hann)
        logm = np.log(np.abs(X) + 1e-9)
        cep = np.fft.irfft(logm)
        cep[lifter:-lifter] = 0.0
        env = np.fft.rfft(cep).real
        env_new = np.interp(freqs / gamma, freqs, env)
        g = np.clip(env_new - env, -max_db / 8.686, max_db / 8.686)
        out[s:s + n] += np.fft.irfft(X * np.exp(g)) * hann
        norm[s:s + n] += hann ** 2
    out = out / np.maximum(norm, 1e-6)
    return out[n:n + len(y)]


def shelf(y, sr, f_c, db, low=True):
    """Gentle shelf via FFT of the whole (looping) signal: circular, so a seamless loop stays seamless."""
    Y = np.fft.rfft(y)
    f = np.fft.rfftfreq(len(y), 1.0 / sr)
    s = 1.0 / (1.0 + (f / f_c) ** 2) if low else 1.0 / (1.0 + (f_c / np.maximum(f, 1e-3)) ** 2)
    return np.fft.irfft(Y * 10 ** (db * s / 20.0), n=len(y))


def stitch(grains, sr, period_s, want_s, xfade_s):
    """Concatenate equal-period grains: each grain is shifted (<= 1 period) to match the tail, then crossfaded."""
    p = max(int(period_s * sr), 8)
    xf = max(int(xfade_s * sr), 2 * p)
    out = None
    gi = 0
    usable = [g for g in grains if len(g) > xf + 2 * p]
    if not usable:
        return None
    while out is None or len(out) < want_s * sr:
        g = usable[gi % len(usable)]
        gi += 1
        if out is None:
            out = g.copy()
            continue
        tail = out[-xf:]
        best, bo = -2.0, 0
        for o in range(0, p):
            seg = g[o:o + xf]
            r = float(np.dot(tail, seg) / (np.sqrt(np.dot(tail, tail) * np.dot(seg, seg)) + 1e-12))
            if r > best:
                best, bo = r, o
        fade = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
        out[-xf:] = tail * (1.0 - fade) + g[bo:bo + xf] * fade
        out = np.concatenate([out, g[bo + xf:]])
        if gi > 400:
            break
    return out
