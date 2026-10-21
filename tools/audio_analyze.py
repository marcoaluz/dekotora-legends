"""Analyse MP3 sounds (run inside Blender: blender -b --factory-startup -P analyze_audio.py -- out.txt file1 file2 ...).

Per file prints:
  dur       duration (s)
  rms       loudness (dBFS)
  flat      spectral flatness 0..1 (noise ~0.3+, pure tone ~0.0x)
  tonal     fraction of energy in the 8 strongest narrow peaks (high = tonal/musical)
  f0s       strongest peak frequencies (Hz)
  pdrift    how much the strongest peak moves over time (semitones, std) -> melody/siren if large and tonal
  beat      strongest periodicity of the loudness envelope in 0.7..4 Hz (42..240 BPM) and its strength 0..1
  seam      loop seam jump: |end - start| relative to typical sample-to-sample step (1 = smooth)
  envvar    envelope variation (std/mean of 50 ms RMS)
"""
import sys
import numpy as np
import aud

args = sys.argv[sys.argv.index("--") + 1:]
out_path = args[0]
import glob
import os
files = []
for a in args[1:]:
    if os.path.isdir(a):
        files += sorted(glob.glob(os.path.join(a, "*.mp3")))
    else:
        files += sorted(glob.glob(a))
lines = []


def analyse(path):
    s = aud.Sound(path)
    rate = int(s.specs[0])
    d = np.asarray(s.data(), dtype=np.float64)
    if d.ndim == 2:
        mono = d.mean(axis=1)
    else:
        mono = d
    n = len(mono)
    dur = n / rate
    rms = 20 * np.log10(np.sqrt(np.mean(mono ** 2)) + 1e-12)
    # spectrum (Welch-like average)
    win = 4096
    hop = 2048
    hann = np.hanning(win)
    frames = []
    peaks_t = []
    for i in range(0, max(1, n - win), hop):
        seg = mono[i:i + win]
        if len(seg) < win:
            break
        sp = np.abs(np.fft.rfft(seg * hann)) ** 2
        frames.append(sp)
    S = np.array(frames)
    freqs = np.fft.rfftfreq(win, 1.0 / rate)
    band = (freqs > 40) & (freqs < 12000)
    P = S.mean(axis=0)
    Pb = P[band]
    fb = freqs[band]
    flat = float(np.exp(np.mean(np.log(Pb + 1e-20))) / (np.mean(Pb) + 1e-20))
    # tonal: energy in narrow peaks (+-2 bins) of the 8 strongest local maxima
    Pc = Pb.copy()
    peak_energy = 0.0
    f0s = []
    for _ in range(8):
        k = int(np.argmax(Pc))
        lo, hi = max(0, k - 2), min(len(Pc), k + 3)
        peak_energy += Pb[lo:hi].sum()
        f0s.append(int(fb[k]))
        Pc[max(0, k - 6):k + 7] = 0
    tonal = float(peak_energy / (Pb.sum() + 1e-20))
    # pitch drift of the strongest peak above 200 Hz over frames (semitones std), weighted by peak prominence
    hb = (freqs > 200) & (freqs < 10000)
    pk = []
    for sp in S:
        k = np.argmax(sp[hb])
        f = freqs[hb][k]
        prom = sp[hb][k] / (np.median(sp[hb]) + 1e-20)
        pk.append((f, prom))
    fr = np.array([p[0] for p in pk])
    pr = np.array([p[1] for p in pk])
    semis = 12 * np.log2(fr / np.median(fr))
    pdrift = float(np.std(semis))
    prom_med = float(np.median(pr))
    # envelope periodicity (rhythm / beat)
    hop_e = int(rate * 0.01)
    env = np.array([np.sqrt(np.mean(mono[i:i + hop_e] ** 2)) for i in range(0, n - hop_e, hop_e)])
    envvar = float(np.std(env) / (np.mean(env) + 1e-12))
    e = env - env.mean()
    ac = np.correlate(e, e, mode="full")[len(e) - 1:]
    ac = ac / (ac[0] + 1e-20)
    lags = np.arange(len(ac)) * 0.01
    sel = (lags >= 0.25) & (lags <= 1.43)
    if sel.any():
        k = int(np.argmax(ac[sel]))
        beat_period = float(lags[sel][k])
        beat_str = float(ac[sel][k])
    else:
        beat_period, beat_str = 0.0, 0.0
    # loop seam
    steps = np.abs(np.diff(mono[: rate // 2]))
    typ = np.percentile(steps, 90) + 1e-9
    seam = float(abs(mono[0] - mono[-1]) / typ)
    # silent padding at the ends (MP3 encoder delay) -> gap/click in a loop
    thr = 1e-3 * np.max(np.abs(mono))
    nz = np.nonzero(np.abs(mono) > thr)[0]
    lead = int(nz[0]) if len(nz) else n
    trail = int(n - 1 - nz[-1]) if len(nz) else n
    # level jump between the last and first 20 ms (loudness discontinuity)
    w20 = int(rate * 0.02)
    jump = 20 * np.log10((np.sqrt(np.mean(mono[-w20:] ** 2)) + 1e-9) / (np.sqrt(np.mean(mono[:w20] ** 2)) + 1e-9))
    seam_txt = f"{seam:.2f} pad={lead}/{trail} jump={jump:+.1f}dB"
    return (f"{path.split('/')[-1]:32s} dur={dur:4.2f}s rms={rms:6.1f}dB flat={flat:.3f} tonal={tonal:.2f} "
            f"prom={prom_med:7.1f} pdrift={pdrift:4.2f}st beat={60/beat_period if beat_period else 0:5.0f}bpm@{beat_str:.2f} "
            f"envvar={envvar:.2f} seam={seam_txt} f0s={f0s[:5]}")


for f in files:
    try:
        lines.append(analyse(f))
    except Exception as ex:  # noqa: BLE001
        lines.append(f"{f}: ERRO {ex}")

with open(out_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
