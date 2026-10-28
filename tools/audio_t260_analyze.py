"""T-260: analyse the 4 real truck recordings (BigSoundBank / SFX Jar, CC0) over time.

    python -I tools/audio_t260_analyze.py DIR_WITH_WAVS [--out docs/audio_t260] [--cyl 4]

For each WAV: duration, sample rate, peak / RMS, loudness envelope (0.1 s), firing-frequency track (YIN on the signal
low-passed to 1 kHz, 0.4 s windows) -> rpm = f x 120 / cylinders, and a guess of what the clip is (idle / steady /
revs). Writes analise.txt and one PNG per file (envelope in dB on top, rpm track below; grey = unclear windows).
The Iveco Daily 3.0 HPI of the recordings is an inline-4 (4 cyl: f x 30 = rpm).
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_plot as ap  # noqa: E402
from audio_t220_analyze import windows_f0, welch  # noqa: E402

CLEAR = 0.45


def track(x, sr, cyl):
    ds = 4000
    lo = ap.resample(ap.fft_lowpass(x, sr, 1000.0), sr, ds)
    f, c = windows_f0(lo, ds, 0.4, 0.1)
    t = 0.2 + 0.1 * np.arange(len(f))
    good = c >= CLEAR
    if good.any():                                          # fold octave errors to the main octave of the clip
        med = np.median(f[good])
        f = f * 2.0 ** np.round(np.log2(med / np.maximum(f, 1e-3)))
    return t, f * 120.0 / cyl, c


def envelope(x, sr, hop=0.1):
    h = int(hop * sr)
    n = len(x) // h
    r = np.sqrt(np.mean(x[:n * h].reshape(n, h) ** 2, axis=1))
    return (np.arange(n) + 0.5) * hop, 20 * np.log10(r + 1e-9)


def segments(t, rpm, c, env_t, env_db):
    """Cut the clip in pieces: steady (rpm within +-4% for >= 1 s) or ramps (rising / falling)."""
    out = []
    good = c >= CLEAR
    i, n = 0, len(t)
    while i < n:
        if not good[i]:
            i += 1
            continue
        j = i
        while j + 1 < n and good[j + 1] and abs(rpm[j + 1] / np.median(rpm[i:j + 2]) - 1) < 0.04:
            j += 1
        if t[j] - t[i] >= 1.0:
            out.append(("estavel", t[i] - 0.2, t[j] + 0.2, float(np.median(rpm[i:j + 1])), float(np.median(rpm[i:j + 1]))))
            i = j + 1
            continue
        # ramp: follow monotone movement
        k = i
        while k + 1 < n and good[k + 1] and abs(rpm[k + 1] / rpm[k] - 1) < 0.12:
            k += 1
        if k > i and t[k] - t[i] >= 0.4:
            kind = "sobe" if rpm[k] > rpm[i] * 1.06 else ("desce" if rpm[k] < rpm[i] * 0.94 else "oscila")
            out.append((kind, t[i] - 0.2, t[k] + 0.2, float(rpm[i]), float(rpm[k])))
            i = k + 1
        else:
            i += 1
    return out


def plot(path, title, env_t, env_db, t, rpm, c, dur):
    W, H = 1000, 380
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = (14, 16, 26)
    ap.text(img, 8, 6, title, (250, 210, 60))
    x0, w = 60, W - 80

    def X(tt):
        return x0 + tt / dur * w
    # envelope (-60..0 dB)
    y0, h = 30, 130
    for db in (0, -20, -40, -60):
        ap.line(img, x0, y0 + (-db) / 60 * h, x0 + w, y0 + (-db) / 60 * h, (40, 44, 60))
        ap.text(img, 8, int(y0 + (-db) / 60 * h) - 3, "%d DB" % db, (120, 125, 140))
    ap.polyline(img, X(env_t), y0 + np.clip(-env_db, 0, 60) / 60 * h, (90, 200, 255))
    # rpm 0..4000
    y1, h1 = 190, 160
    for r in (0, 1000, 2000, 3000, 4000):
        yy = y1 + h1 - r / 4000 * h1
        ap.line(img, x0, yy, x0 + w, yy, (40, 44, 60))
        ap.text(img, 8, int(yy) - 3, "%d" % r, (120, 125, 140))
    for k in range(len(t)):
        col = (60, 220, 110) if c[k] >= CLEAR else (70, 70, 80)
        yy = int(y1 + h1 - np.clip(rpm[k], 0, 4000) / 4000 * h1)
        xx = int(X(t[k]))
        img[max(yy - 1, 0):yy + 2, max(xx - 1, 0):xx + 2] = col
    for s in range(0, int(dur) + 1, 5):
        ap.text(img, int(X(s)) - 4, H - 14, "%dS" % s, (120, 125, 140))
    ap.text(img, x0, y1 - 14, "RPM (4 CIL.: FREQUENCIA DAS EXPLOSOES X 30)  VERDE = RITMO CLARO", (150, 150, 160))
    ap.save_png(path, img)


def main():
    a = sys.argv[1:]
    src = a[0]
    out = a[a.index("--out") + 1] if "--out" in a else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "audio_t260")
    cyl = int(a[a.index("--cyl") + 1]) if "--cyl" in a else 4
    os.makedirs(out, exist_ok=True)
    lines = []
    for nm in sorted(os.listdir(src)):
        if not nm.lower().endswith(".wav"):
            continue
        p = os.path.join(src, nm)
        with wave.open(p, "rb") as wv:
            ch, sw = wv.getnchannels(), wv.getsampwidth()
        x, sr = ap.read_wav(p)
        x = x - np.mean(x)
        dur = len(x) / sr
        env_t, env_db = envelope(x, sr)
        t, rpm, c = track(x, sr, cyl)
        good = c >= CLEAR
        freqs, P = welch(x, sr)
        tot = P[freqs >= 20].sum()
        low = P[(freqs >= 20) & (freqs < 300)].sum() / tot
        hi = P[freqs >= 2000].sum() / tot
        cen = float((freqs * P).sum() / P.sum())
        lines.append("== %s" % nm)
        lines.append("   %.2f s, %d Hz, %d canal(is), %d bits; pico %.1f dBFS, RMS %.1f dBFS; faixa de volume (p10..p90) %.1f..%.1f dB"
                     % (dur, sr, ch, sw * 8, 20 * np.log10(np.max(np.abs(x)) + 1e-12), 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12),
                        np.percentile(env_db, 10), np.percentile(env_db, 90)))
        if good.any():
            lines.append("   rpm (%d cil.) com ritmo claro em %d%% das janelas: min %.0f, mediana %.0f, max %.0f (p5 %.0f, p95 %.0f)"
                         % (cyl, 100 * good.mean(), rpm[good].min(), np.median(rpm[good]), rpm[good].max(),
                            np.percentile(rpm[good], 5), np.percentile(rpm[good], 95)))
        lines.append("   energia < 300 Hz %.0f%%, > 2 kHz %.0f%%, centro do espectro %.0f Hz" % (100 * low, 100 * hi, cen))
        for s in segments(t, rpm, c, env_t, env_db):
            lines.append("   %-7s %5.1f-%5.1f s  %4.0f -> %4.0f rpm" % s)
        plot(os.path.join(out, os.path.splitext(nm)[0] + "_analise.png"), nm.upper(), env_t, env_db, t, rpm, c, dur)
    txt = "\n".join(lines)
    print(txt)
    with open(os.path.join(out, "analise.txt"), "w", encoding="utf-8") as f:
        f.write(txt + "\n")


if __name__ == "__main__":
    main()
