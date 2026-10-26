"""T-220: compare recordings of the --ramp script (tools/render_t220_audio.sh) with what a real 6-cylinder diesel does.

    python tools/audio_t220_compare.py OUT_DIR a.wav b.wav ...

The ramp (scenes/tools/engine_audio_test.tscn --ramp): idle 2 s, full throttle 8 s from 700 to 2400 rpm, hold 1 s,
lift off 4 s back to 700, idle 2 s. Expected firing frequency = rpm / 20 (6 cyl, 4-stroke).
Writes OUT_DIR/rampa_comparacao.png (per file: spectrogram 20 Hz..4 kHz with the expected firing line in green, and
the measured fundamental (red) over the expected one (green)) and OUT_DIR/rampa_comparacao.txt.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_plot as ap  # noqa: E402
from audio_t220_analyze import yin  # noqa: E402

RAMP = [2.0, 10.0, 11.0, 15.0, 17.0]
IDLE, REDLINE, CYL = 700.0, 2400.0, 6
LATENCY = 0.08          # generator buffer + first frame


def rpm_at(t):
    t = t - LATENCY
    if t < RAMP[0]:
        r = 0.0
    elif t < RAMP[1]:
        r = (t - RAMP[0]) / (RAMP[1] - RAMP[0])
    elif t < RAMP[2]:
        r = 1.0
    elif t < RAMP[3]:
        r = 1.0 - (t - RAMP[2]) / (RAMP[3] - RAMP[2])
    else:
        r = 0.0
    return IDLE + r * (REDLINE - IDLE)


def periodicity(x, sr, win=0.3, hop=0.15):
    """Normalised autocorrelation at the expected firing period (+-3%) on the 200 Hz..4 kHz band (what a phone
    speaker plays): 1 = every firing identical (machine-like), real engines are rougher. Returns (times, values)."""
    y = ap.fft_lowpass(x, sr, 4000.0)
    Y = np.fft.rfft(y)
    f = np.fft.rfftfreq(len(y), 1.0 / sr)
    Y[f < 200.0] = 0.0
    y = np.fft.irfft(Y, n=len(y))
    w, h = int(win * sr), int(hop * sr)
    ts, rs = [], []
    for i in range(0, len(y) - 2 * w, h):
        t = (i + w / 2) / sr
        T = sr / (rpm_at(t) / 20.0)
        a = y[i:i + w]
        best = -1.0
        for lag in range(int(T * 0.97), int(T * 1.03) + 1):
            b = y[i + lag:i + lag + w]
            best = max(best, float(np.dot(a, b) / (np.sqrt(np.dot(a, a) * np.dot(b, b)) + 1e-12)))
        ts.append(t)
        rs.append(best)
    return np.array(ts), np.array(rs)


def track(x, sr, win=0.25, hop=0.05):
    ds = 4000
    lo = ap.resample(ap.fft_lowpass(x, sr, 900.0), sr, ds)
    w, h = int(win * ds), int(hop * ds)
    ts, fs, cs = [], [], []
    for i in range(0, len(lo) - w, h):
        f, c = yin(lo[i:i + w] - np.mean(lo[i:i + w]), ds, 20.0, 300.0)
        ts.append((i + w / 2) / ds)
        fs.append(f)
        cs.append(c)
    return np.array(ts), np.array(fs), np.array(cs)


FMIN, FMAX = 20.0, 4000.0
W, SH, TH = 900, 150, 110


def spectro(img, ox, oy, x, sr, dur):
    win = 4096
    hop = max(1, int((len(x) - win) / W))
    hann = np.hanning(win)
    f = np.fft.rfftfreq(win, 1.0 / sr)
    edges = np.geomspace(FMIN, FMAX, SH + 1)
    idx = [np.where((f >= edges[k]) & (f < edges[k + 1]))[0] for k in range(SH)]
    cols = []
    for c in range(W):
        seg = x[c * hop:c * hop + win]
        if len(seg) < win:
            seg = np.pad(seg, (0, win - len(seg)))
        p = np.abs(np.fft.rfft(seg * hann)) ** 2
        cols.append([p[ii].mean() if len(ii) else p[np.argmin(np.abs(f - edges[k]))] for k, ii in enumerate(idx)])
    m = 10 * np.log10(np.array(cols).T + 1e-14)
    m = np.clip((m - (m.max() - 65.0)) / 65.0, 0, 1)[::-1]
    rgb = np.stack([np.clip(m * 3 - 1.5, 0, 1), np.clip(m * 2 - 0.4, 0, 1) * 0.9, np.clip(1.2 - np.abs(m * 2 - 0.9), 0, 1) * m], -1)
    img[oy:oy + SH, ox:ox + W] = (rgb * 255).astype(np.uint8)
    for c in range(0, W, 2):
        fe = rpm_at(c / W * dur) / 20.0
        y = oy + SH - 1 - int(np.log(fe / FMIN) / np.log(FMAX / FMIN) * SH)
        if oy <= y < oy + SH:
            img[y, ox + c] = (60, 255, 110)


def tplot(img, ox, oy, ts, fs, cs, dur):
    ap.rect(img, ox, oy, ox + W, oy + TH, (14, 16, 26))
    fmax = 160.0
    for g in (25, 50, 75, 100, 125, 150):
        y = oy + TH - g / fmax * TH
        ap.line(img, ox, y, ox + W - 1, y, (40, 44, 60))
        ap.text(img, ox + 2, int(y) - 8, str(g), (120, 125, 140))
    ex = [rpm_at(c / W * dur) / 20.0 for c in range(W)]
    ap.polyline(img, list(range(ox, ox + W)), [oy + TH - e / fmax * TH for e in ex], (60, 220, 110))
    for t, f, c in zip(ts, fs, cs):
        if c < 0.4:
            continue
        x = ox + int(t / dur * W)
        y = int(oy + TH - min(f, fmax) / fmax * TH)
        ap.rect(img, x - 1, y - 1, x + 2, y + 2, (255, 70, 70) if c >= 0.6 else (140, 60, 60))


def main():
    out, files = sys.argv[1], sys.argv[2:]
    rows = []
    txt = ["T-220 rampa 700 -> 2400 rpm (6 cil.): fundamental medida x esperada (rpm/20)",
           "%-28s %8s %8s %8s %8s %8s %8s %9s %9s" % ("arquivo", "rms dB", "segue%", "clareza", "<300Hz%", "lenta Hz", "corte Hz",
                                                       "period.ac", "period.le")]
    for p in files:
        x, sr = ap.read_wav(p)
        dur = len(x) / sr
        ts, fs, cs = track(x, sr)
        exp = np.array([rpm_at(t) / 20.0 for t in ts])
        okw = (cs >= 0.5) & (np.abs(fs / exp - 1.0) < 0.10)
        accel = (ts > RAMP[0] + 0.5) & (ts < RAMP[1])
        follow = 100.0 * okw[accel].mean() if accel.any() else 0.0
        clar = float(np.median(cs[accel])) if accel.any() else 0.0
        P = np.abs(np.fft.rfft(x)) ** 2
        f = np.fft.rfftfreq(len(x), 1.0 / sr)
        low = 100.0 * P[(f >= 20) & (f < 300)].sum() / max(P[f >= 20].sum(), 1e-20)
        idle = (ts > 0.4) & (ts < RAMP[0] - 0.1)
        top = (ts > RAMP[1] + 0.1) & (ts < RAMP[2] - 0.1)
        fi = float(np.median(fs[idle])) if idle.any() else 0.0
        ft = float(np.median(fs[top])) if top.any() else 0.0
        rms = 20 * np.log10(np.sqrt(np.mean(x[int(0.3 * sr):] ** 2)) + 1e-12)
        name = os.path.splitext(os.path.basename(p))[0]
        pt, pr = periodicity(x, sr)
        pa = float(np.median(pr[(pt > RAMP[0] + 0.5) & (pt < RAMP[1])]))
        pi = float(np.median(pr[(pt > 0.4) & (pt < RAMP[0] - 0.2)]))
        txt.append("%-28s %8.1f %7.0f%% %8.2f %7.0f%% %8.1f %8.1f %9.2f %9.2f" % (name, rms, follow, clar, low, fi, ft, pa, pi))
        rows.append((name, x, sr, dur, ts, fs, cs, follow, fi, ft))
    txt.append("period.ac/le = periodicidade 200 Hz-4 kHz acelerando / em lenta (1 = toda explosao igual, cara de maquina)")
    txt.append("segue% = janelas da aceleracao com fundamental a +-10% da esperada; lenta esperada 35 Hz, corte 120 Hz.")
    img = np.zeros((40 + len(rows) * (SH + TH + 40), W + 20, 3), np.uint8)
    img[:] = (6, 7, 12)
    ap.text(img, 10, 8, "RAMPA 700 -> 2400 RPM, 6 CILINDROS: ESPERADO RPM/20 HZ", (250, 210, 60), 2)
    ap.text(img, 10, 26, "EM CIMA: ESPECTROGRAMA 20 HZ-4 KHZ, LINHA VERDE = IGNICAO ESPERADA. EMBAIXO: F0 MEDIDA (VERMELHO) X ESPERADA (VERDE), 0-160 HZ", (120, 125, 140))
    y = 40
    for name, x, sr, dur, ts, fs, cs, follow, fi, ft in rows:
        ap.text(img, 10, y + 2, "%s   SEGUE O MOTOR %.0f%%   LENTA %.0f HZ (35)   CORTE %.0f HZ (120)" % (name, follow, fi, ft), (235, 235, 235))
        spectro(img, 10, y + 14, x, sr, dur)
        tplot(img, 10, y + 16 + SH, ts, fs, cs, dur)
        y += SH + TH + 40
    ap.save_png(os.path.join(out, "rampa_comparacao.png"), img)
    with open(os.path.join(out, "rampa_comparacao.txt"), "w", encoding="utf-8") as fo:
        fo.write("\n".join(txt) + "\n")
    print("\n".join(txt))


if __name__ == "__main__":
    main()
