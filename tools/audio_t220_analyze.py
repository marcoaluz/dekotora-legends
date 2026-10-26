"""T-220: objective check of every engine loop (system Python + numpy only).

    python tools/audio_t220_analyze.py [--decoded DIR] [--out docs/audio_t220]

A 4-stroke diesel fires every cylinder once per 2 revolutions, so the firing (fundamental) frequency is
    f = rpm / 60 * cylinders / 2        (6 cyl: rpm/20 -> 700 rpm = 35 Hz, 2500 rpm = 125 Hz; V8: rpm/15; 4 cyl: rpm/30)
For each loop the script knows at which RPM and at which pitch_scale the game plays it (EngineAudio / DieselMix),
so it can compare the fundamental the player HEARS (measured in the file x pitch) with the one a real engine has.

Measures per loop:
  f0      fundamental of the file (YIN on the signal low-passed to 1 kHz, median of 0.5 s windows)
  clarity how periodic the file is (1 = a clear firing rhythm, < 0.6 = noise / no rhythm)
  drift   how much f0 moves inside the loop (semitones, robust std = 1.48 x median absolute deviation) -> "tone changing inside the file"
  rhythm  f0 of the loudness envelope (the "chug"; second opinion for noisy files)
  harm    share of the 20..1500 Hz energy that sits on the expected harmonics (k x f, +-4%)
  low     share of the energy below 300 Hz (a phone speaker plays almost nothing there)
Verdict CERTO = clarity >= 0.6, heard f0 within +-15% of expected and drift < 0.7 semitone.

The MP3 loops (ElevenLabs) must be decoded first (Blender has ffmpeg):
    blender -b --factory-startup -P tools/audio_decode.py -- DIR game/assets/audio/engines/*.mp3
Outputs in --out: analise.txt, analise.json (read by the test scene) and one PNG sheet per family.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_plot as ap  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ENG_DIR = os.path.join(ROOT, "game", "assets", "audio", "engines")
IDLE = 700.0
REDLINE = {"i6_std": 2400.0, "i6_tuned": 2600.0, "v8": 2500.0}
CENTERS4 = [0.0, 0.3, 0.62, 0.95]
CENTERS3 = [0.0, 0.5, 0.95]
SYN_POINTS = [700, 1000, 1400, 1900, 2500]
SYN_CYL = {"i6": 6, "i6t": 6, "v8": 8, "i4": 4}


def firing_hz(rpm, cyl):
    return rpm / 60.0 * cyl / 2.0


def legacy_jobs():
    """(name, file, cylinders, rpm where the game plays it loudest, pitch_scale at that rpm, family)"""
    out = []
    for es, cyl in (("i6_std", 6), ("i6_tuned", 6), ("v8", 8)):
        for band, c in zip(["idle", "low", "mid", "high"], CENTERS4):
            rpm = IDLE + c * (REDLINE[es] - IDLE)
            out.append((es + "_" + band, es + "_" + band, cyl, rpm, 0.78 + 0.62 * c, "elevenlabs"))
    for prof in ("exh_rasp", "exh_stack", "exh_pop"):          # exhaust profiles, here on the 6-cyl standard
        for band, c in zip(["idle", "mid", "high"], CENTERS3):
            rpm = IDLE + c * (REDLINE["i6_std"] - IDLE)
            out.append((prof + "_" + band, prof + "_" + band, 6, rpm, 0.78 + 0.62 * c, "elevenlabs"))
    out.append(("exhaust_straight_layer", "exhaust_straight_layer", 6, 1550.0, 0.85 + 0.4 * 0.5, "elevenlabs"))
    return out


def syn_jobs():
    out = []
    for v, cyl in SYN_CYL.items():
        for kind in ("on", "off"):
            for r in SYN_POINTS:
                out.append(("syn_%s_%s_%d" % (v, kind, r), "syn_%s_%s_%d" % (v, kind, r), cyl, float(r), 1.0, "t197_" + v))
    return out


# ------------------------------------------------------------------ measurement
def yin(x, sr, fmin=15.0, fmax=300.0, thresh=0.3):
    """Returns (f0, clarity) of one window. Cumulative-mean-normalised difference, first dip under thresh."""
    tmin, tmax = int(sr / fmax), int(sr / fmin)
    n = len(x) - tmax
    if n < tmax:
        return 0.0, 0.0
    X = np.fft.rfft(x, 2 * len(x))
    ac = np.fft.irfft(X * np.conj(X))[:tmax + 1]
    e = np.cumsum(x ** 2)
    e0 = e[n - 1]
    lag = np.arange(tmax + 1)
    ek = e[np.minimum(n - 1 + lag, len(e) - 1)] - np.concatenate([[0.0], e[:tmax]])
    d = e0 + ek - 2.0 * ac
    d[0] = 0.0
    cm = d[1:] * np.arange(1, tmax + 1) / np.maximum(np.cumsum(d[1:]), 1e-12)
    cm = np.concatenate([[1.0], cm])
    tau = -1
    for t in range(tmin, tmax):
        if cm[t] < thresh:
            while t + 1 < tmax and cm[t + 1] < cm[t]:
                t += 1
            tau = t
            break
    if tau < 0:
        tau = tmin + int(np.argmin(cm[tmin:tmax]))
    a, b, c = cm[tau - 1], cm[tau], cm[min(tau + 1, tmax)]
    den = a - 2 * b + c
    shift = 0.5 * (a - c) / den if abs(den) > 1e-12 else 0.0
    return sr / (tau + shift), float(np.clip(1.0 - b, 0.0, 1.0))


def windows_f0(x, sr, win_s=0.5, hop_s=0.25):
    w, h = int(win_s * sr), int(hop_s * sr)
    res = [yin(x[i:i + w], sr) for i in range(0, max(1, len(x) - w), h)]
    f = np.array([r[0] for r in res])
    c = np.array([r[1] for r in res])
    return f, c


def welch(x, sr):
    win = 1 << int(np.log2(max(8192, min(65536, len(x) // 2))))
    if win > len(x):
        win = 1 << int(np.log2(len(x)))
    hop = win // 4
    hann = np.hanning(win)
    acc = np.zeros(win // 2 + 1)
    k = 0
    for i in range(0, len(x) - win + 1, hop):
        acc += np.abs(np.fft.rfft(x[i:i + win] * hann)) ** 2
        k += 1
    return np.fft.rfftfreq(win, 1.0 / sr), acc / max(k, 1)


def analyse(x, sr, cyl, rpm, pitch):
    x = x - np.mean(x)
    exp_heard = firing_hz(rpm, cyl)
    exp_native = exp_heard / pitch
    ds = 4000
    lo = ap.resample(ap.fft_lowpass(x, sr, 1000.0), sr, ds)
    f, c = windows_f0(lo, ds)
    good = c >= 0.5
    f0 = float(np.median(f[good] if good.any() else f))
    clarity = float(np.median(c))
    st = 12.0 * np.log2(np.maximum(f[good] if good.any() else f, 1e-3) / max(f0, 1e-3))
    drift = float(1.4826 * np.median(np.abs(st)))          # robust spread (an odd octave-jump window does not count)
    env = np.abs(x)
    env = ap.resample(ap.fft_lowpass(env, sr, 400.0), sr, ds)
    env -= np.mean(env)
    fe, ce = windows_f0(env, ds)
    rhythm = float(np.median(fe))
    freqs, P = welch(x, sr)
    band = (freqs >= 20) & (freqs <= 1500)
    on = np.zeros_like(band)
    for k in range(1, 40):
        fk = k * exp_native
        if fk > 1500:
            break
        on |= (freqs >= fk * 0.96) & (freqs <= fk * 1.04)
    harm = float(P[band & on].sum() / max(P[band].sum(), 1e-20))
    cover = float((band & on).sum() / max(band.sum(), 1))
    low = float(P[(freqs >= 20) & (freqs < 300)].sum() / max(P[freqs >= 20].sum(), 1e-20))
    heard = f0 * pitch
    ratio = heard / exp_heard
    reasons = []
    if clarity < 0.6:
        reasons.append("sem ritmo de ignicao claro (clareza %.2f)" % clarity)
    if abs(ratio - 1.0) > 0.15:
        oct_note = ""
        for m, nm in ((2.0, "o dobro"), (0.5, "a metade"), (1.0 / 3.0, "1/3"), (3.0, "o triplo")):
            if abs(ratio / m - 1.0) < 0.1:
                oct_note = " (= %s)" % nm
        reasons.append("fundamental ouvida %.0f Hz x esperada %.0f Hz (%+.0f%%)%s" % (heard, exp_heard, (ratio - 1) * 100, oct_note))
    if drift >= 0.7:
        reasons.append("tom muda dentro do loop (%.1f semitons)" % drift)
    return {"f0": f0, "clarity": clarity, "drift": drift, "rhythm": rhythm, "harm": harm, "harm_noise": cover,
            "low": low, "heard": heard, "expected": exp_heard, "expected_native": exp_native, "pitch": pitch,
            "rpm": rpm, "cyl": cyl, "ratio": ratio, "ok": not reasons, "reasons": reasons,
            "dur": len(x) / sr, "rms_db": float(20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)),
            "_spec": (freqs, P)}


# ------------------------------------------------------------------ plotting
BG, GRID, AX = (14, 16, 26), (40, 44, 60), (120, 125, 140)
GREEN, RED, YEL, CYAN, WHITE = (60, 220, 110), (255, 70, 70), (250, 210, 60), (90, 200, 255), (235, 235, 235)
PW, PH = 560, 190
FMIN, FMAX = 20.0, 4000.0


def fx(f, x0, w):
    return x0 + (np.log10(f) - np.log10(FMIN)) / (np.log10(FMAX) - np.log10(FMIN)) * w


def panel(img, ox, oy, name, r):
    ap.rect(img, ox, oy, ox + PW - 6, oy + PH - 6, BG)
    x0, y0, w, h = ox + 34, oy + 40, PW - 50, PH - 66
    for g in (20, 50, 100, 200, 500, 1000, 2000, 4000):
        ap.vline(img, fx(g, x0, w), y0, y0 + h, GRID)
        ap.text(img, int(fx(g, x0, w)) - 6, y0 + h + 4, str(g) if g < 1000 else "%dK" % (g // 1000), AX)
    freqs, P = r["_spec"]
    m = (freqs >= FMIN) & (freqs <= FMAX)
    db = 10 * np.log10(P[m] + 1e-20)
    top = db.max()
    dbn = np.clip((db - (top - 60.0)) / 60.0, 0, 1)
    xs = fx(freqs[m], x0, w)
    # one point per pixel column (max), keeps narrow peaks visible
    cols = np.round(xs).astype(int)
    ux = np.unique(cols)
    ys = np.array([dbn[cols == u].max() for u in ux])
    for k in range(1, 13):
        fk = k * r["expected_native"]
        if fk <= FMAX:
            ap.vline(img, fx(fk, x0, w), y0, y0 + h, GREEN if k == 1 else (40, 120, 70), dash=3)
    ap.polyline(img, ux, y0 + h - ys * h, CYAN)
    ap.vline(img, fx(max(r["f0"], FMIN), x0, w), y0, y0 + h, RED)
    col = GREEN if r["ok"] else RED
    ap.text(img, ox + 6, oy + 6, "%s  %s" % (name, "CERTO" if r["ok"] else "ERRADO"), col)
    ap.text(img, ox + 6, oy + 18, "%.0f RPM  TOCA X%.2f  OUVIDA %.1f HZ  ESPERADA %.1f HZ  CLAREZA %.2f" %
            (r["rpm"], r["pitch"], r["heard"], r["expected"], r["clarity"]), WHITE)
    ap.text(img, ox + 6, oy + 28, "NO ARQUIVO %.1f HZ  RITMO %.1f HZ  VARIA %.1f ST  HARM %.0f%%  <300HZ %.0f%%" %
            (r["f0"], r["rhythm"], r["drift"], 100 * r["harm"], 100 * r["low"]), AX)


def sheet(path, title, items, cols=2):
    rows = (len(items) + cols - 1) // cols
    img = np.zeros((40 + rows * PH, cols * PW, 3), np.uint8)
    img[:] = (6, 7, 12)
    ap.text(img, 8, 8, title, YEL, 2)
    ap.text(img, 8, 26, "AZUL = ESPECTRO (60 DB)  VERMELHO = F0 MEDIDA NO ARQUIVO  VERDE = HARMONICAS ESPERADAS NO ARQUIVO (1A MAIS FORTE)", AX)
    for i, (name, r) in enumerate(items):
        panel(img, (i % cols) * PW, 40 + (i // cols) * PH, name, r)
    ap.save_png(path, img)


def main():
    args = sys.argv[1:]
    dec = args[args.index("--decoded") + 1] if "--decoded" in args else os.path.join(ROOT, "..", "tmp_t220", "decoded")
    out = args[args.index("--out") + 1] if "--out" in args else os.path.join(ROOT, "docs", "audio_t220")
    os.makedirs(out, exist_ok=True)
    results = {}
    for name, fname, cyl, rpm, pitch, fam in legacy_jobs() + syn_jobs():
        path = os.path.join(dec, fname + ".wav") if fam == "elevenlabs" else os.path.join(ENG_DIR, fname + ".wav")
        if not os.path.exists(path):
            print("FALTA", path)
            continue
        x, sr = ap.read_wav(path)
        r = analyse(x, sr, cyl, rpm, pitch)
        r["family"] = fam
        results[name] = r
    lines = ["T-220 analise dos loops do motor (fundamental de ignicao = rpm/60 x cilindros/2)",
             "%-24s %-6s %6s %5s %7s %7s %5s %5s %5s %5s %4s  %s" % ("loop", "veredi", "rpm", "x", "ouvida", "esper.",
                                                                  "clar", "varia", "harm", "ruido", "<300", "motivo")]
    for name, r in results.items():
        lines.append("%-24s %-6s %6.0f %5.2f %7.1f %7.1f %5.2f %5.1f %4.0f%% %4.0f%% %3.0f%%  %s" % (
            name, "CERTO" if r["ok"] else "ERRADO", r["rpm"], r["pitch"], r["heard"], r["expected"], r["clarity"],
            r["drift"], 100 * r["harm"], 100 * r["harm_noise"], 100 * r["low"], "; ".join(r["reasons"])))
    with open(os.path.join(out, "analise.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    js = {k: {kk: vv for kk, vv in v.items() if not kk.startswith("_")} for k, v in results.items()}
    with open(os.path.join(out, "analise.json"), "w", encoding="utf-8") as f:
        json.dump(js, f, indent=1)
    fams = {}
    for name, r in results.items():
        fams.setdefault(r["family"], []).append((name, r))
    titles = {"elevenlabs": "LOOPS ELEVENLABS (SOM ANTIGO, --ENGINE-SOUND=OLD)",
              "t197_i6": "SINTETIZADOS T-197, 6 CILINDROS PADRAO (SOM ATUAL DO JOGO)",
              "t197_i6t": "SINTETIZADOS T-197, 6 CILINDROS PREPARADO", "t197_v8": "SINTETIZADOS T-197, V8",
              "t197_i4": "SINTETIZADOS T-197, 4 CILINDROS (CANTER)"}
    for fam, items in fams.items():
        p = os.path.join(out, "espectro_%s.png" % fam)
        sheet(p, titles.get(fam, fam), items)
        print("PNG", p)


if __name__ == "__main__":
    main()
